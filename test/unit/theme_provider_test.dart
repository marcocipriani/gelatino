import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/models/user_settings.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/theme_provider.dart';
import 'package:gelatino/repositories/profile_repository.dart';

void main() {
  test('build restores local theme synchronously without any write', () {
    final fixture = ThemeFixture.create(localTheme: 'dark', uid: null);
    addTearDown(fixture.dispose);

    expect(fixture.container.read(themeModeProvider), ThemeMode.dark);
    expect(fixture.preferences.writes, isEmpty);
    expect(fixture.repository.themeModeUpdates, isEmpty);
  });

  test('invalid local theme falls back synchronously to system', () {
    final fixture = ThemeFixture.create(localTheme: 'sepia', uid: null);
    addTearDown(fixture.dispose);

    expect(fixture.container.read(themeModeProvider), ThemeMode.system);
    expect(fixture.preferences.writes, isEmpty);
  });

  test(
    'remote controller refreshes state and records one local write',
    () async {
      final fixture = ThemeFixture.create(localTheme: 'light');
      addTearDown(fixture.dispose);
      fixture.container.read(themeModeProvider);

      await fixture.container
          .read(themeModeProvider.notifier)
          .applyRemoteThemeMode(uid: 'alice', value: 'dark');

      expect(fixture.container.read(themeModeProvider), ThemeMode.dark);
      expect(fixture.preferences.writes, <String>['dark']);
      expect(fixture.repository.themeModeUpdates, isEmpty);
    },
  );

  test(
    'failed remote snapshot persistence retries and then deduplicates',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'light',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.preferences.failuresRemaining = 1;
      fixture.container.read(themeModeProvider);

      final update = fixture.container
          .read(themeModeProvider.notifier)
          .applyRemoteThemeMode(uid: 'alice', value: 'dark');
      expect(await scheduler.firstScheduled.future, 1);
      expect(fixture.preferences.writeAttempts, <String>['dark']);
      scheduler.releaseNext();
      await update;
      await fixture.container
          .read(themeModeProvider.notifier)
          .applyRemoteThemeMode(uid: 'alice', value: 'dark');

      expect(fixture.preferences.writeAttempts, <String>['dark', 'dark']);
      expect(fixture.preferences.writes, <String>['dark']);
      expect(errors, hasLength(1));
    },
  );

  test(
    'user theme change records one local and one theme-only write',
    () async {
      final fixture = ThemeFixture.create(localTheme: 'light');
      addTearDown(fixture.dispose);
      fixture.container.read(themeModeProvider);

      await fixture.container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(fixture.container.read(themeModeProvider), ThemeMode.dark);
      expect(fixture.preferences.writes, <String>['dark']);
      expect(fixture.repository.themeModeUpdates, <(String, String)>[
        ('alice', 'dark'),
      ]);
      expect(fixture.repository.profileUpdates, isEmpty);
    },
  );

  test('sign-out retains local theme and clears user settings', () async {
    final fixture = ThemeFixture.create(localTheme: 'light');
    addTearDown(fixture.dispose);
    fixture.container.read(themeModeProvider);
    await fixture.container
        .read(themeModeProvider.notifier)
        .applyRemoteThemeMode(uid: 'alice', value: 'dark');

    fixture.setUid(null);

    expect(await fixture.container.read(ownSettingsProvider.future), isNull);
    expect(fixture.container.read(defaultCollectionViewProvider), isNull);
    expect(fixture.container.read(themeModeProvider), ThemeMode.dark);
    expect(fixture.preferences.writes, <String>['dark']);
  });

  test(
    'user change skips every remote patch when identity switches mid-write',
    () async {
      final preferences = ControlledThemePreferences('light')..prepare('dark');
      final fixture = ControlledThemeFixture.create(
        preferences: preferences,
        uid: 'alice',
      );
      addTearDown(fixture.dispose);

      final update = fixture.container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await preferences.firstAttempt.future;
      fixture.setUid('bob');
      preferences.complete('dark');
      await update;

      expect(fixture.repository.themeModeAttempts, isEmpty);
      expect(fixture.repository.themeModeUpdates, isEmpty);
    },
  );

  test(
    'remote queue is serialized latest-wins and deduplicates final value',
    () async {
      final preferences = ControlledThemePreferences('system')
        ..prepare('dark')
        ..prepare('light');
      final fixture = ControlledThemeFixture.create(
        preferences: preferences,
        uid: 'alice',
      );
      addTearDown(fixture.dispose);
      final notifier = fixture.container.read(themeModeProvider.notifier);

      final dark = notifier.applyRemoteThemeMode(uid: 'alice', value: 'dark');
      await preferences.firstAttempt.future;
      final light = notifier.applyRemoteThemeMode(uid: 'alice', value: 'light');

      expect(fixture.container.read(themeModeProvider), ThemeMode.light);
      expect(preferences.writeAttempts, <String>['dark']);
      preferences.complete('light');
      preferences.complete('dark');
      await Future.wait(<Future<void>>[dark, light]);

      expect(preferences.writeAttempts, <String>['dark', 'light']);
      expect(preferences.value, 'light');
      expect(fixture.container.read(themeModeProvider), ThemeMode.light);

      await notifier.applyRemoteThemeMode(uid: 'alice', value: 'light');
      expect(preferences.writeAttempts, <String>['dark', 'light']);
    },
  );

  test('local latest-wins does not wait for a blocked remote patch', () async {
    final fixture = ThemeFixture.create(localTheme: 'system');
    addTearDown(fixture.dispose);
    fixture.repository.prepareThemeUpdate('dark');
    final notifier = fixture.container.read(themeModeProvider.notifier);

    final dark = notifier.setThemeMode(ThemeMode.dark);
    expect(await fixture.repository.firstThemeAttempt.future, (
      'alice',
      'dark',
    ));
    expect(fixture.preferences.value, 'dark');

    final light = notifier.setThemeMode(ThemeMode.light);

    expect(fixture.preferences.value, 'light');
    expect(fixture.preferences.writeAttempts, <String>['dark', 'light']);
    expect(fixture.repository.themeModeAttempts, <(String, String)>[
      ('alice', 'dark'),
    ]);

    fixture.repository.completeThemeUpdate('dark');
    await Future.wait(<Future<void>>[dark, light]);

    expect(fixture.repository.themeModeAttempts, <(String, String)>[
      ('alice', 'dark'),
      ('alice', 'light'),
    ]);
    expect(fixture.repository.themeModeUpdates.last, ('alice', 'light'));
    expect(fixture.preferences.value, 'light');
  });

  test('account switch drops remote work queued behind an old patch', () async {
    final fixture = ThemeFixture.create(localTheme: 'system');
    addTearDown(fixture.dispose);
    fixture.repository.prepareThemeUpdate('dark');
    final notifier = fixture.container.read(themeModeProvider.notifier);

    final dark = notifier.setThemeMode(ThemeMode.dark);
    await fixture.repository.firstThemeAttempt.future;
    final light = notifier.setThemeMode(ThemeMode.light);
    expect(fixture.preferences.value, 'light');

    fixture.setUid('bob');
    await Future.wait(<Future<void>>[dark, light]);
    fixture.repository.completeThemeUpdate('dark');
    await fixture.repository.firstThemeUpdate.future;

    expect(fixture.repository.themeModeAttempts, <(String, String)>[
      ('alice', 'dark'),
    ]);
    expect(
      fixture.repository.themeModeAttempts.where(
        (update) => update.$1 == 'bob',
      ),
      isEmpty,
    );
  });

  test(
    'remote emission from an old UID is ignored after account switch',
    () async {
      final fixture = ThemeFixture.create(localTheme: 'light');
      addTearDown(fixture.dispose);
      fixture.setUid('bob');

      await fixture.container
          .read(themeModeProvider.notifier)
          .applyRemoteThemeMode(uid: 'alice', value: 'dark');

      expect(fixture.container.read(themeModeProvider), ThemeMode.light);
      expect(fixture.preferences.writeAttempts, isEmpty);
      expect(fixture.preferences.writes, isEmpty);
    },
  );

  test(
    'remote dedupe cache does not survive a new identity generation',
    () async {
      final fixture = ThemeFixture.create(localTheme: 'dark');
      addTearDown(fixture.dispose);
      final notifier = fixture.container.read(themeModeProvider.notifier);
      await notifier.applyRemoteThemeMode(uid: 'alice', value: 'dark');

      fixture.setUid('bob');
      fixture.setUid('alice');
      await notifier.setThemeMode(ThemeMode.dark);

      expect(fixture.repository.themeModeUpdates, <(String, String)>[
        ('alice', 'dark'),
      ]);
    },
  );

  test(
    'failed local persistence retries automatically before remote',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'light',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.preferences.failuresRemaining = 1;

      final update = fixture.container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(await scheduler.firstScheduled.future, 1);

      expect(fixture.preferences.writeAttempts, <String>['dark']);
      expect(fixture.repository.themeModeAttempts, isEmpty);
      scheduler.releaseNext();
      await update;

      expect(fixture.preferences.writeAttempts, <String>['dark', 'dark']);
      expect(fixture.preferences.writes, <String>['dark']);
      expect(fixture.repository.themeModeUpdates, <(String, String)>[
        ('alice', 'dark'),
      ]);
      expect(errors, hasLength(1));
    },
  );

  test('failed remote persistence retries without rewriting local', () async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final scheduler = ManualThemeRetryScheduler();
    final fixture = ThemeFixture.create(
      localTheme: 'light',
      retryScheduler: scheduler,
    );
    addTearDown(fixture.dispose);
    fixture.repository.themeFailuresRemaining = 1;

    final update = fixture.container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    expect(await scheduler.firstScheduled.future, 1);

    expect(fixture.preferences.writeAttempts, <String>['dark']);
    expect(fixture.repository.themeModeAttempts, <(String, String)>[
      ('alice', 'dark'),
    ]);
    scheduler.releaseNext();
    await update;

    expect(fixture.preferences.writeAttempts, <String>['dark']);
    expect(errors, hasLength(1));
    expect(fixture.repository.themeModeAttempts, <(String, String)>[
      ('alice', 'dark'),
      ('alice', 'dark'),
    ]);
    expect(fixture.repository.themeModeUpdates, <(String, String)>[
      ('alice', 'dark'),
    ]);
  });

  test(
    'theme attempt feedback reports local failure then exact retry success',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'light',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.preferences.failuresRemaining = 1;
      final notifier = fixture.container.read(themeModeProvider.notifier);

      final failure = expectLater(
        notifier.setThemeModeWithFeedback(ThemeMode.dark),
        throwsA(isA<StateError>()),
      );
      expect(await scheduler.firstScheduled.future, 1);
      await failure;
      expect(fixture.preferences.writeAttempts, <String>['dark']);

      final retry = notifier.setThemeModeWithFeedback(ThemeMode.dark);
      scheduler.releaseNext();
      await retry;

      expect(fixture.preferences.writeAttempts, <String>['dark', 'dark']);
      expect(fixture.preferences.writes, <String>['dark']);
      expect(fixture.repository.themeModeUpdates, <(String, String)>[
        ('alice', 'dark'),
      ]);
      expect(errors, hasLength(1));
    },
  );

  test(
    'theme attempt feedback reports remote failure then retry without local rewrite',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'light',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.repository.themeFailuresRemaining = 1;
      final notifier = fixture.container.read(themeModeProvider.notifier);

      final failure = expectLater(
        notifier.setThemeModeWithFeedback(ThemeMode.dark),
        throwsA(isA<StateError>()),
      );
      expect(await scheduler.firstScheduled.future, 1);
      await failure;
      expect(fixture.preferences.writeAttempts, <String>['dark']);
      expect(fixture.repository.themeModeAttempts, <(String, String)>[
        ('alice', 'dark'),
      ]);

      final retry = notifier.setThemeModeWithFeedback(ThemeMode.dark);
      scheduler.releaseNext();
      await retry;

      expect(fixture.preferences.writeAttempts, <String>['dark']);
      expect(fixture.repository.themeModeAttempts, <(String, String)>[
        ('alice', 'dark'),
        ('alice', 'dark'),
      ]);
      expect(errors, hasLength(1));
    },
  );

  test(
    'new theme attempt feedback supersedes an older failed intent',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'system',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.preferences.failuresRemaining = 1;
      final notifier = fixture.container.read(themeModeProvider.notifier);

      final darkFailure = expectLater(
        notifier.setThemeModeWithFeedback(ThemeMode.dark),
        throwsA(isA<StateError>()),
      );
      expect(await scheduler.firstScheduled.future, 1);
      await darkFailure;

      await notifier.setThemeModeWithFeedback(ThemeMode.light);
      scheduler.releaseNext();
      await Future<void>.delayed(Duration.zero);

      expect(fixture.preferences.writeAttempts, <String>['dark', 'light']);
      expect(fixture.container.read(themeModeProvider), ThemeMode.light);
      expect(fixture.repository.themeModeUpdates, <(String, String)>[
        ('alice', 'light'),
      ]);
      expect(errors, hasLength(1));
    },
  );

  test('new light intent supersedes a dark local retry immediately', () async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final scheduler = ManualThemeRetryScheduler();
    final fixture = ThemeFixture.create(
      localTheme: 'light',
      retryScheduler: scheduler,
    );
    addTearDown(fixture.dispose);
    fixture.preferences.failuresRemaining = 1;
    final notifier = fixture.container.read(themeModeProvider.notifier);

    final dark = notifier.setThemeMode(ThemeMode.dark);
    expect(await scheduler.firstScheduled.future, 1);
    await notifier.setThemeMode(ThemeMode.light);

    expect(fixture.container.read(themeModeProvider), ThemeMode.light);
    expect(fixture.preferences.writeAttempts, <String>['dark']);
    expect(fixture.repository.themeModeUpdates, <(String, String)>[
      ('alice', 'light'),
    ]);
    scheduler.releaseNext();
    await dark;
    expect(fixture.preferences.writeAttempts, <String>['dark']);
    expect(errors, hasLength(1));
  });

  test(
    'identity switch cancels a dirty retry before old persistence',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final scheduler = ManualThemeRetryScheduler();
      final fixture = ThemeFixture.create(
        localTheme: 'light',
        retryScheduler: scheduler,
      );
      addTearDown(fixture.dispose);
      fixture.preferences.failuresRemaining = 1;

      final dark = fixture.container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(await scheduler.firstScheduled.future, 1);
      fixture.setUid('bob');
      await dark;

      expect(fixture.preferences.writeAttempts, <String>['dark']);
      expect(fixture.preferences.value, 'light');
      expect(fixture.repository.themeModeAttempts, isEmpty);
      expect(errors, hasLength(1));
    },
  );

  test('throwing retry scheduler cancels bounded dirty intents', () async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final scheduler = ThrowingThenBlockingThemeRetryScheduler();
    final fixture = ThemeFixture.create(
      localTheme: 'system',
      retryScheduler: scheduler,
    );
    addTearDown(fixture.dispose);
    fixture.preferences.alwaysFail = true;
    final notifier = fixture.container.read(themeModeProvider.notifier);

    await notifier.setThemeMode(ThemeMode.dark);

    expect(fixture.preferences.writeAttempts, <String>['dark']);
    expect(scheduler.waitCalls, 1);
    expect(errors, hasLength(2));

    scheduler.throwOnNextWait();
    await notifier.setThemeMode(ThemeMode.light);

    expect(fixture.preferences.writeAttempts, <String>['dark', 'light']);
    expect(scheduler.waitCalls, 2);
    expect(errors, hasLength(4));
  });

  test('theme source has no persistence or scheduling in build', () {
    final source = File('lib/providers/theme_provider.dart').readAsStringSync();

    expect(source, isNot(contains('SharedPreferences.getInstance')));
    expect(source, isNot(contains('FirebaseAuth.instance')));
    expect(source, isNot(contains('scheduleMicrotask')));
    expect(source, isNot(contains('ownSettingsProvider')));
  });

  test(
    'settings routes theme persistence through its async field boundary',
    () {
      final profile = File(
        'lib/screens/profile_screen.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/screens/settings_screen.dart',
      ).readAsStringSync();

      expect(profile, isNot(contains('.setThemeMode(')));
      expect(settings, contains("field: 'theme'"));
      expect(settings, contains('.setThemeModeWithFeedback(selection)'));
      expect(settings, contains('Future<void> _runFieldAction'));
    },
  );
}

final class ThemeFixture {
  ThemeFixture._(
    this.container,
    this.repository,
    this.preferences,
    this._retryScheduler,
    this._themeSubscription,
    this._settingsSubscription,
  );

  final ProviderContainer container;
  final FakeProfileRepository repository;
  final RecordingThemePreferences preferences;
  final ThemeRetryScheduler? _retryScheduler;
  final ProviderSubscription<ThemeMode> _themeSubscription;
  final ProviderSubscription<AsyncValue<UserSettings?>> _settingsSubscription;

  static ThemeFixture create({
    required String localTheme,
    String? uid = 'alice',
    ThemeRetryScheduler? retryScheduler,
  }) {
    final preferences = RecordingThemePreferences(localTheme);
    final repository = FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        profileRepositoryProvider.overrideWithValue(repository),
        themePreferencesProvider.overrideWithValue(preferences),
        if (retryScheduler != null)
          themeRetrySchedulerProvider.overrideWithValue(retryScheduler),
      ],
    );
    final themeSubscription = container.listen(
      themeModeProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    final settingsSubscription = container.listen(
      ownSettingsProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    container.read(themeModeProvider.notifier).synchronizeIdentity(uid);
    return ThemeFixture._(
      container,
      repository,
      preferences,
      retryScheduler,
      themeSubscription,
      settingsSubscription,
    );
  }

  void setUid(String? uid) {
    container.updateOverrides([
      currentUidProvider.overrideWithValue(uid),
      profileRepositoryProvider.overrideWithValue(repository),
      themePreferencesProvider.overrideWithValue(preferences),
      if (_retryScheduler != null)
        themeRetrySchedulerProvider.overrideWithValue(_retryScheduler),
    ]);
    container.read(themeModeProvider.notifier).synchronizeIdentity(uid);
  }

  void dispose() {
    _themeSubscription.close();
    _settingsSubscription.close();
    container.dispose();
  }
}

final class ManualThemeRetryScheduler implements ThemeRetryScheduler {
  final Completer<int> firstScheduled = Completer<int>();
  final List<Completer<void>> _scheduled = <Completer<void>>[];

  @override
  Future<void> wait(int failureCount) {
    if (!firstScheduled.isCompleted) firstScheduled.complete(failureCount);
    final completer = Completer<void>();
    _scheduled.add(completer);
    return completer.future;
  }

  void releaseNext() => _scheduled.removeAt(0).complete();
}

final class ThrowingThenBlockingThemeRetryScheduler
    implements ThemeRetryScheduler {
  int waitCalls = 0;
  bool _throwNext = true;
  final Completer<void> _unexpectedRetry = Completer<void>();

  void throwOnNextWait() => _throwNext = true;

  @override
  Future<void> wait(int failureCount) {
    waitCalls++;
    if (_throwNext) {
      _throwNext = false;
      throw StateError('retry scheduler failed');
    }
    return _unexpectedRetry.future;
  }
}

final class RecordingThemePreferences implements ThemePreferences {
  RecordingThemePreferences(this.value);

  String? value;
  int failuresRemaining = 0;
  bool alwaysFail = false;
  final List<String> writeAttempts = <String>[];
  final List<String> writes = <String>[];

  @override
  String? readThemeMode() => value;

  @override
  Future<void> writeThemeMode(String value) async {
    writeAttempts.add(value);
    if (alwaysFail || failuresRemaining > 0) {
      if (failuresRemaining > 0) failuresRemaining--;
      throw StateError('preferences failed');
    }
    this.value = value;
    writes.add(value);
  }
}

final class ControlledThemePreferences implements ThemePreferences {
  ControlledThemePreferences(this.value);

  String? value;
  final List<String> writeAttempts = <String>[];
  final List<String> writes = <String>[];
  final Completer<String> firstAttempt = Completer<String>();
  final Map<String, Completer<void>> _completions = <String, Completer<void>>{};

  void prepare(String value) {
    _completions[value] = Completer<void>();
  }

  void complete(String value) => _completions[value]!.complete();

  @override
  String? readThemeMode() => value;

  @override
  Future<void> writeThemeMode(String value) async {
    writeAttempts.add(value);
    if (!firstAttempt.isCompleted) firstAttempt.complete(value);
    await _completions[value]!.future;
    this.value = value;
    writes.add(value);
  }
}

final class ControlledThemeFixture {
  ControlledThemeFixture._(
    this.container,
    this.repository,
    this.preferences,
    this._themeSubscription,
    this._settingsSubscription,
  );

  final ProviderContainer container;
  final FakeProfileRepository repository;
  final ControlledThemePreferences preferences;
  final ProviderSubscription<ThemeMode> _themeSubscription;
  final ProviderSubscription<AsyncValue<UserSettings?>> _settingsSubscription;

  static ControlledThemeFixture create({
    required ControlledThemePreferences preferences,
    required String? uid,
  }) {
    final repository = FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        profileRepositoryProvider.overrideWithValue(repository),
        themePreferencesProvider.overrideWithValue(preferences),
      ],
    );
    final themeSubscription = container.listen(
      themeModeProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    final settingsSubscription = container.listen(
      ownSettingsProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    container.read(themeModeProvider.notifier).synchronizeIdentity(uid);
    return ControlledThemeFixture._(
      container,
      repository,
      preferences,
      themeSubscription,
      settingsSubscription,
    );
  }

  void setUid(String? uid) {
    container.updateOverrides([
      currentUidProvider.overrideWithValue(uid),
      profileRepositoryProvider.overrideWithValue(repository),
      themePreferencesProvider.overrideWithValue(preferences),
    ]);
    container.read(themeModeProvider.notifier).synchronizeIdentity(uid);
  }

  void dispose() {
    _themeSubscription.close();
    _settingsSubscription.close();
    container.dispose();
  }
}

final class FakeProfileRepository implements ProfileRepository {
  int themeFailuresRemaining = 0;
  final Completer<(String, String)> firstThemeAttempt =
      Completer<(String, String)>();
  final Completer<(String, String)> firstThemeUpdate =
      Completer<(String, String)>();
  final Map<String, Completer<void>> _themeUpdateGates =
      <String, Completer<void>>{};
  final List<(String, String)> themeModeAttempts = [];
  final List<(String, String)> themeModeUpdates = [];
  final List<(String, ProfilePatch)> profileUpdates = [];

  @override
  Future<void> updateDefaultCollectionView(
    String uid,
    String defaultCollectionView,
  ) async {}

  @override
  Future<void> updatePrivacy(String uid, {required bool isPrivate}) async {}

  @override
  Future<void> updateThemeMode(String uid, String themeMode) async {
    themeModeAttempts.add((uid, themeMode));
    if (!firstThemeAttempt.isCompleted) {
      firstThemeAttempt.complete((uid, themeMode));
    }
    final gate = _themeUpdateGates[themeMode];
    if (gate != null) await gate.future;
    if (themeFailuresRemaining > 0) {
      themeFailuresRemaining--;
      throw StateError('theme repository failed');
    }
    themeModeUpdates.add((uid, themeMode));
    if (!firstThemeUpdate.isCompleted) {
      firstThemeUpdate.complete((uid, themeMode));
    }
  }

  void prepareThemeUpdate(String value) {
    _themeUpdateGates[value] = Completer<void>();
  }

  void completeThemeUpdate(String value) {
    _themeUpdateGates.remove(value)!.complete();
  }

  @override
  Future<void> updateProfile(String uid, ProfilePatch patch) async {
    profileUpdates.add((uid, patch));
  }

  @override
  Future<void> ensureOwnProfile({
    required String uid,
    required String displayName,
  }) async {}

  @override
  Stream<UserProfile?> watchOwnProfile(String uid) =>
      Stream<UserProfile?>.value(null);

  @override
  Stream<UserSettings?> watchOwnSettings(String uid) =>
      Stream<UserSettings?>.value(null);

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) =>
      Stream<PublicProfile?>.value(null);

  @override
  Future<PublicProfile?> readPublicProfile(String uid) async => null;

  @override
  Future<List<PublicProfile>> searchPublicProfiles(
    String query, {
    int limit = 20,
  }) async => const <PublicProfile>[];
}
