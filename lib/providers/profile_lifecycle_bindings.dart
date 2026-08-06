import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_settings.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';
import 'profile_providers.dart';
import 'theme_provider.dart';

final class OwnerProfileIdentity {
  const OwnerProfileIdentity({required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is OwnerProfileIdentity &&
      other.uid == uid &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, displayName);
}

final ownerProfileIdentityProvider = Provider<OwnerProfileIdentity?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return OwnerProfileIdentity(
    uid: uid,
    displayName: ref.watch(currentUserDisplayNameProvider) ?? 'Utente Goloso',
  );
});

abstract interface class OwnerBootstrapRetryScheduler {
  Future<void> wait(int failureCount);
}

final class TimerOwnerBootstrapRetryScheduler
    implements OwnerBootstrapRetryScheduler {
  const TimerOwnerBootstrapRetryScheduler();

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

final ownerBootstrapRetrySchedulerProvider =
    Provider<OwnerBootstrapRetryScheduler>((ref) {
      return const TimerOwnerBootstrapRetryScheduler();
    });

final class OwnerProfileBootstrap {
  OwnerProfileBootstrap(this._repository, this._retryScheduler);

  final ProfileRepository _repository;
  final OwnerBootstrapRetryScheduler _retryScheduler;
  final Set<String> _completedUids = <String>{};
  OwnerProfileIdentity? _currentIdentity;
  int _generation = 0;
  String? _activeUid;
  int? _activeGeneration;
  Future<void>? _activeOperation;

  Future<void> handleIdentity(OwnerProfileIdentity? identity) {
    if (_currentIdentity?.uid != identity?.uid) _generation++;
    _currentIdentity = identity;
    if (identity == null || _completedUids.contains(identity.uid)) {
      return Future<void>.value();
    }
    if (_activeUid == identity.uid && _activeGeneration == _generation) {
      return _activeOperation ?? Future<void>.value();
    }

    final generation = _generation;
    late final Future<void> operation;
    operation = _bootstrap(identity, generation).whenComplete(() {
      if (identical(_activeOperation, operation)) {
        _activeUid = null;
        _activeGeneration = null;
        _activeOperation = null;
      }
    });
    _activeUid = identity.uid;
    _activeGeneration = generation;
    _activeOperation = operation;
    return operation;
  }

  Future<void> _bootstrap(OwnerProfileIdentity identity, int generation) async {
    var failureCount = 0;
    while (_isCurrent(identity.uid, generation)) {
      try {
        await _repository.ensureOwnProfile(
          uid: identity.uid,
          displayName: identity.displayName,
        );
        _completedUids.add(identity.uid);
        return;
      } catch (error, stackTrace) {
        failureCount++;
        _reportBootstrapError(identity.uid, error, stackTrace);
      }
      if (!_isCurrent(identity.uid, generation)) return;
      try {
        await _retryScheduler.wait(failureCount);
      } catch (error, stackTrace) {
        _reportBootstrapError(identity.uid, error, stackTrace);
        return;
      }
    }
  }

  bool _isCurrent(String uid, int generation) =>
      _generation == generation && _currentIdentity?.uid == uid;

  void _reportBootstrapError(String uid, Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while bootstrapping owner profile $uid'),
      ),
    );
  }
}

final ownerProfileBootstrapProvider = Provider<OwnerProfileBootstrap>((ref) {
  return OwnerProfileBootstrap(
    ref.watch(profileRepositoryProvider),
    ref.watch(ownerBootstrapRetrySchedulerProvider),
  );
});

class ProfileLifecycleBindings extends ConsumerStatefulWidget {
  const ProfileLifecycleBindings({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProfileLifecycleBindings> createState() =>
      _ProfileLifecycleBindingsState();
}

class _ProfileLifecycleBindingsState
    extends ConsumerState<ProfileLifecycleBindings> {
  late final ProviderSubscription<OwnerProfileIdentity?> _identitySubscription;
  late final ProviderSubscription<AsyncValue<UserSettings?>>
  _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _identitySubscription = ref.listenManual(ownerProfileIdentityProvider, (
      previous,
      next,
    ) {
      ref.read(themeModeProvider.notifier).synchronizeIdentity(next?.uid);
      unawaited(ref.read(ownerProfileBootstrapProvider).handleIdentity(next));
    }, fireImmediately: true);
    _settingsSubscription = ref.listenManual(ownSettingsProvider, (
      previous,
      next,
    ) {
      if (next case AsyncData<UserSettings?>(value: final settings?)) {
        final uid = ref.read(currentUidProvider);
        if (uid == null) return;
        unawaited(
          ref
              .read(themeModeProvider.notifier)
              .applyRemoteThemeMode(uid: uid, value: settings.themeMode),
        );
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _identitySubscription.close();
    _settingsSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
