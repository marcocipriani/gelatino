import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_providers.dart';
import 'auth_provider.dart';
import 'profile_providers.dart';

const themeModePreferenceKey = 'gelatino_theme_mode';

abstract interface class ThemePreferences {
  String? readThemeMode();

  Future<void> writeThemeMode(String value);
}

final class SharedPreferencesThemePreferences implements ThemePreferences {
  SharedPreferencesThemePreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? readThemeMode() => _preferences.getString(themeModePreferenceKey);

  @override
  Future<void> writeThemeMode(String value) {
    return _preferences.setString(themeModePreferenceKey, value);
  }
}

final themePreferencesProvider = Provider<ThemePreferences>((ref) {
  return SharedPreferencesThemePreferences(
    ref.watch(sharedPreferencesProvider),
  );
});

abstract interface class ThemeRetryScheduler {
  Future<void> wait(int failureCount);
}

final class TimerThemeRetryScheduler implements ThemeRetryScheduler {
  const TimerThemeRetryScheduler();

  static const List<Duration> _delays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  @override
  Future<void> wait(int failureCount) {
    final index = (failureCount - 1).clamp(0, _delays.length - 1);
    return Future<void>.delayed(_delays[index]);
  }
}

final themeRetrySchedulerProvider = Provider<ThemeRetryScheduler>((ref) {
  return const TimerThemeRetryScheduler();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  late ThemePreferences _preferences;
  late ThemeRetryScheduler _retryScheduler;
  String? _activeUid;
  int _identityGeneration = 0;
  int _intentVersion = 0;
  String? _lastLocalValue;
  final Map<String, String> _lastRemoteValueByUid = <String, String>{};
  _ThemeIntent? _currentIntent;
  _ThemeIntent? _activeLocalAttempt;
  _ThemeIntent? _pendingLocalIntent;
  bool _isLocalDraining = false;
  _ThemeIntent? _activeRemoteAttempt;
  _ThemeIntent? _pendingRemoteIntent;
  bool _isRemoteDraining = false;

  @override
  ThemeMode build() {
    _preferences = ref.watch(themePreferencesProvider);
    _retryScheduler = ref.watch(themeRetrySchedulerProvider);
    final mode = _themeModeFromStorage(_preferences.readThemeMode());
    _lastLocalValue = _serializeThemeMode(mode);
    return mode;
  }

  void synchronizeIdentity(String? uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _identityGeneration++;
    _intentVersion++;
    if (uid != null) _lastRemoteValueByUid.remove(uid);
    final staleIntent = _currentIntent;
    _currentIntent = null;
    _pendingLocalIntent = null;
    _pendingRemoteIntent = null;
    staleIntent?.complete();
  }

  Future<void> applyRemoteThemeMode({
    required String uid,
    required String value,
  }) {
    if (_activeUid != uid || ref.read(currentUidProvider) != uid) {
      return Future<void>.value();
    }
    final mode = _themeModeFromStorage(value);
    final serialized = _serializeThemeMode(mode);
    _lastRemoteValueByUid[uid] = serialized;
    state = mode;
    return _submitIntent(value: serialized, uid: uid, patchRemote: false);
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _setThemeMode(mode, waitForAttempt: false);
  }

  Future<void> setThemeModeWithFeedback(ThemeMode mode) {
    return _setThemeMode(mode, waitForAttempt: true);
  }

  Future<void> _setThemeMode(ThemeMode mode, {required bool waitForAttempt}) {
    final capturedUid = ref.read(currentUidProvider);
    synchronizeIdentity(capturedUid);
    state = mode;
    final serialized = _serializeThemeMode(mode);
    return _submitIntent(
      value: serialized,
      uid: capturedUid,
      patchRemote: capturedUid != null,
      waitForAttempt: waitForAttempt,
    );
  }

  Future<void> _submitIntent({
    required String value,
    required String? uid,
    required bool patchRemote,
    bool waitForAttempt = false,
  }) {
    final current = _currentIntent;
    if (current != null &&
        _isCurrent(current) &&
        current.matches(value: value, uid: uid, patchRemote: patchRemote)) {
      return waitForAttempt ? current.addAttemptWaiter() : current.addWaiter();
    }

    final intent = _ThemeIntent(
      value: value,
      uid: uid,
      generation: _identityGeneration,
      version: ++_intentVersion,
      patchRemote: patchRemote,
    );
    final waiter = waitForAttempt
        ? intent.addAttemptWaiter()
        : intent.addWaiter();
    current?.complete();
    _currentIntent = intent;
    _pendingLocalIntent = null;
    _pendingRemoteIntent = null;
    _queueLocalAttempt(intent);
    return waiter;
  }

  void _queueLocalAttempt(_ThemeIntent intent) {
    if (!_isCurrent(intent) || identical(_pendingLocalIntent, intent)) return;
    _pendingLocalIntent = intent;
    _startLocalDrain();
  }

  void _startLocalDrain() {
    if (_isLocalDraining) return;
    _isLocalDraining = true;
    unawaited(_drainLocal());
  }

  Future<void> _drainLocal() async {
    while (_pendingLocalIntent != null) {
      final intent = _pendingLocalIntent!;
      _pendingLocalIntent = null;
      if (!_isCurrent(intent)) {
        intent.complete();
        continue;
      }
      _activeLocalAttempt = intent;
      try {
        await _executeLocalAttempt(intent);
      } catch (error, stackTrace) {
        _reportThemeError(
          'while serializing local theme updates',
          error,
          stackTrace,
        );
        intent.failAttempt(error, stackTrace);
        if (_isCurrent(intent)) {
          _scheduleRetry(intent, _ThemeRetryLane.local, 1);
        }
      } finally {
        if (identical(_activeLocalAttempt, intent)) {
          _activeLocalAttempt = null;
        }
      }

      if (!_isCurrent(intent)) continue;
      if (intent.localSettled) {
        _queueRemoteAttempt(intent);
      } else if (!intent.localRetryScheduled) {
        _pendingLocalIntent = intent;
      }
    }
    _isLocalDraining = false;
    if (_pendingLocalIntent != null) _startLocalDrain();
  }

  Future<void> _executeLocalAttempt(_ThemeIntent intent) async {
    if (!_isCurrent(intent)) return;
    if (_lastLocalValue != intent.value) {
      try {
        await _preferences.writeThemeMode(intent.value);
        _lastLocalValue = intent.value;
        intent.localFailureCount = 0;
      } catch (error, stackTrace) {
        intent.localFailureCount++;
        _reportThemeError(
          'while persisting theme mode locally',
          error,
          stackTrace,
        );
        intent.failAttempt(error, stackTrace);
        _scheduleRetry(intent, _ThemeRetryLane.local, intent.localFailureCount);
        return;
      }
    }
    if (_isCurrent(intent)) intent.localSettled = true;
  }

  void _queueRemoteAttempt(_ThemeIntent intent) {
    if (!_isCurrent(intent) || identical(_pendingRemoteIntent, intent)) return;
    _pendingRemoteIntent = intent;
    _startRemoteDrain();
  }

  void _startRemoteDrain() {
    if (_isRemoteDraining) return;
    _isRemoteDraining = true;
    unawaited(_drainRemote());
  }

  Future<void> _drainRemote() async {
    while (_pendingRemoteIntent != null) {
      final intent = _pendingRemoteIntent!;
      _pendingRemoteIntent = null;
      if (!_isCurrent(intent)) {
        intent.complete();
        continue;
      }
      _activeRemoteAttempt = intent;
      try {
        await _executeRemoteAttempt(intent);
      } catch (error, stackTrace) {
        _reportThemeError(
          'while serializing remote theme updates',
          error,
          stackTrace,
        );
        intent.failAttempt(error, stackTrace);
        if (_isCurrent(intent)) {
          _scheduleRetry(intent, _ThemeRetryLane.remote, 1);
        }
      } finally {
        if (identical(_activeRemoteAttempt, intent)) {
          _activeRemoteAttempt = null;
        }
      }

      if (!_isCurrent(intent)) continue;
      if (intent.remoteSettled) {
        _completeIfSettled(intent);
      } else if (!intent.remoteRetryScheduled) {
        _pendingRemoteIntent = intent;
      }
    }
    _isRemoteDraining = false;
    if (_pendingRemoteIntent != null) _startRemoteDrain();
  }

  Future<void> _executeRemoteAttempt(_ThemeIntent intent) async {
    if (!_isCurrent(intent) || !intent.localSettled) return;
    final needsRemoteWrite =
        intent.patchRemote &&
        intent.uid != null &&
        _lastRemoteValueByUid[intent.uid] != intent.value;
    if (needsRemoteWrite) {
      try {
        await ref
            .read(profileRepositoryProvider)
            .updateThemeMode(intent.uid!, intent.value);
        _lastRemoteValueByUid[intent.uid!] = intent.value;
        intent.remoteFailureCount = 0;
      } catch (error, stackTrace) {
        intent.remoteFailureCount++;
        _reportThemeError(
          'while persisting theme mode remotely for ${intent.uid}',
          error,
          stackTrace,
        );
        intent.failAttempt(error, stackTrace);
        _scheduleRetry(
          intent,
          _ThemeRetryLane.remote,
          intent.remoteFailureCount,
        );
        return;
      }
    }
    if (_isCurrent(intent)) intent.remoteSettled = true;
  }

  void _completeIfSettled(_ThemeIntent intent) {
    if (!_isCurrent(intent) ||
        !intent.localSettled ||
        !intent.remoteSettled ||
        intent.localRetryScheduled ||
        intent.remoteRetryScheduled) {
      return;
    }
    _currentIntent = null;
    if (identical(_pendingLocalIntent, intent)) _pendingLocalIntent = null;
    if (identical(_pendingRemoteIntent, intent)) _pendingRemoteIntent = null;
    intent.complete();
  }

  void _scheduleRetry(
    _ThemeIntent intent,
    _ThemeRetryLane lane,
    int failureCount,
  ) {
    if (!_isCurrent(intent) || intent.isRetryScheduled(lane)) return;
    intent.setRetryScheduled(lane, true);
    unawaited(_waitAndRetry(intent, lane, failureCount));
  }

  Future<void> _waitAndRetry(
    _ThemeIntent intent,
    _ThemeRetryLane lane,
    int failureCount,
  ) async {
    try {
      await _retryScheduler.wait(failureCount);
    } catch (error, stackTrace) {
      _reportThemeError(
        'while scheduling theme persistence retry',
        error,
        stackTrace,
      );
      intent.failAttempt(error, stackTrace);
      intent.setRetryScheduled(lane, false);
      _cancelIntent(intent);
      return;
    }
    intent.setRetryScheduled(lane, false);
    if (!_isCurrent(intent)) {
      intent.complete();
      return;
    }
    switch (lane) {
      case _ThemeRetryLane.local:
        _queueLocalAttempt(intent);
      case _ThemeRetryLane.remote:
        _queueRemoteAttempt(intent);
    }
  }

  void _cancelIntent(_ThemeIntent intent) {
    if (identical(_currentIntent, intent)) _currentIntent = null;
    if (identical(_pendingLocalIntent, intent)) _pendingLocalIntent = null;
    if (identical(_pendingRemoteIntent, intent)) _pendingRemoteIntent = null;
    intent.complete();
  }

  bool _isCurrent(_ThemeIntent intent) =>
      identical(_currentIntent, intent) &&
      intent.generation == _identityGeneration &&
      intent.version == _intentVersion &&
      intent.uid == _activeUid &&
      ref.read(currentUidProvider) == intent.uid;

  void _reportThemeError(String context, Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription(context),
      ),
    );
  }
}

final class _ThemeIntent {
  _ThemeIntent({
    required this.value,
    required this.uid,
    required this.generation,
    required this.version,
    required this.patchRemote,
  });

  final String value;
  final String? uid;
  final int generation;
  final int version;
  final bool patchRemote;
  bool localSettled = false;
  bool remoteSettled = false;
  bool localRetryScheduled = false;
  bool remoteRetryScheduled = false;
  int localFailureCount = 0;
  int remoteFailureCount = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];
  final List<Completer<void>> _attemptWaiters = <Completer<void>>[];

  bool matches({
    required String value,
    required String? uid,
    required bool patchRemote,
  }) =>
      this.value == value && this.uid == uid && this.patchRemote == patchRemote;

  bool isRetryScheduled(_ThemeRetryLane lane) => switch (lane) {
    _ThemeRetryLane.local => localRetryScheduled,
    _ThemeRetryLane.remote => remoteRetryScheduled,
  };

  void setRetryScheduled(_ThemeRetryLane lane, bool value) {
    switch (lane) {
      case _ThemeRetryLane.local:
        localRetryScheduled = value;
      case _ThemeRetryLane.remote:
        remoteRetryScheduled = value;
    }
  }

  Future<void> addWaiter() {
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  Future<void> addAttemptWaiter() {
    final completer = Completer<void>();
    _attemptWaiters.add(completer);
    return completer.future;
  }

  void failAttempt(Object error, StackTrace stackTrace) {
    for (final waiter in _attemptWaiters) {
      if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
    }
    _attemptWaiters.clear();
  }

  void complete() {
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
    for (final waiter in _attemptWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _attemptWaiters.clear();
  }
}

enum _ThemeRetryLane { local, remote }

ThemeMode _themeModeFromStorage(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  'system' || _ => ThemeMode.system,
};

String _serializeThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
