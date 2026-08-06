import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/models/user_settings.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_lifecycle_bindings.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/theme_provider.dart';
import 'package:gelatino/repositories/profile_repository.dart';

void main() {
  test(
    'owner bootstrap runs once per UID across change and sign-out',
    () async {
      final repository = RecordingProfileRepository();
      addTearDown(repository.dispose);
      final bootstrap = OwnerProfileBootstrap(
        repository,
        ManualOwnerBootstrapRetryScheduler(),
      );
      const alice = OwnerProfileIdentity(uid: 'alice', displayName: 'Alice');
      const bob = OwnerProfileIdentity(uid: 'bob', displayName: 'Bob');

      await Future.wait([
        bootstrap.handleIdentity(alice),
        bootstrap.handleIdentity(alice),
      ]);
      await bootstrap.handleIdentity(null);
      await bootstrap.handleIdentity(bob);
      await bootstrap.handleIdentity(alice);

      expect(repository.ensureCalls, <OwnerProfileIdentity>[alice, bob]);
    },
  );

  testWidgets(
    'root lifecycle bootstraps owner even when child is a public deep-link',
    (tester) async {
      final repository = RecordingProfileRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWithValue('alice'),
            currentUserDisplayNameProvider.overrideWithValue('Alice'),
            profileRepositoryProvider.overrideWithValue(repository),
          ],
          child: const ProfileLifecycleBindings(
            child: MaterialApp(home: Text('public profile deep-link')),
          ),
        ),
      );

      await repository.firstEnsure.future;

      expect(find.text('public profile deep-link'), findsOneWidget);
      expect(repository.ensureCalls, const <OwnerProfileIdentity>[
        OwnerProfileIdentity(uid: 'alice', displayName: 'Alice'),
      ]);
    },
  );

  testWidgets('root lifecycle follows UID changes and sign-out once per UID', (
    tester,
  ) async {
    final repository = RecordingProfileRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => ref.watch(_testUidProvider)),
          currentUserDisplayNameProvider.overrideWithValue('Test User'),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
        child: const ProfileLifecycleBindings(
          child: MaterialApp(home: Text('deep-link')),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('deep-link')),
    );
    await repository.firstEnsure.future;

    final bobEnsure = Completer<void>();
    repository.nextEnsure = bobEnsure;
    container.read(_testUidProvider.notifier).setUid('bob');
    await tester.pump();
    await bobEnsure.future;
    container.read(_testUidProvider.notifier).setUid(null);
    await tester.pump();

    expect(container.read(ownerProfileIdentityProvider), isNull);
    expect(repository.ensureCalls.map((identity) => identity.uid), [
      'alice',
      'bob',
    ]);

    container.read(_testUidProvider.notifier).setUid('alice');
    await tester.pump();
    expect(repository.ensureCalls.map((identity) => identity.uid), [
      'alice',
      'bob',
    ]);
  });

  testWidgets('failed bootstrap retries automatically after injected backoff', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final repository = RecordingProfileRepository()
      ..ensureFailuresByUid['alice'] = 1;
    final scheduler = ManualOwnerBootstrapRetryScheduler();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
          ownerBootstrapRetrySchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const ProfileLifecycleBindings(
          child: MaterialApp(home: Text('deep-link')),
        ),
      ),
    );
    await scheduler.firstScheduled.future;
    final secondAttempt = repository.nextEnsureAttempt;

    scheduler.releaseNext();
    expect(
      await secondAttempt,
      const OwnerProfileIdentity(uid: 'alice', displayName: 'Alice'),
    );
    await repository.firstEnsure.future;
    FlutterError.onError = previous;

    expect(repository.ensureAttempts, hasLength(2));
    expect(repository.ensureCalls, hasLength(1));
    expect(errors, hasLength(1));
  });

  testWidgets('sign-out generation guards a scheduled bootstrap retry', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final repository = RecordingProfileRepository()
      ..ensureFailuresByUid['alice'] = 2;
    final scheduler = ManualOwnerBootstrapRetryScheduler();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => ref.watch(_testUidProvider)),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
          ownerBootstrapRetrySchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const ProfileLifecycleBindings(
          child: MaterialApp(home: Text('deep-link')),
        ),
      ),
    );
    await scheduler.firstScheduled.future;

    final container = ProviderScope.containerOf(
      tester.element(find.text('deep-link')),
    );
    container.read(_testUidProvider.notifier).setUid(null);
    await tester.pump();
    scheduler.releaseNext();
    await tester.pump();
    FlutterError.onError = previous;

    expect(repository.ensureAttempts.map((identity) => identity.uid), [
      'alice',
    ]);
    expect(errors, hasLength(1));
  });

  testWidgets('same UID re-login detaches the stale retry generation', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final repository = RecordingProfileRepository()
      ..ensureFailuresByUid['alice'] = 1;
    final scheduler = ManualOwnerBootstrapRetryScheduler();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => ref.watch(_testUidProvider)),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
          ownerBootstrapRetrySchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const ProfileLifecycleBindings(
          child: MaterialApp(home: Text('deep-link')),
        ),
      ),
    );
    await scheduler.firstScheduled.future;
    final container = ProviderScope.containerOf(
      tester.element(find.text('deep-link')),
    );

    container.read(_testUidProvider.notifier).setUid(null);
    await tester.pump();
    container.read(_testUidProvider.notifier).setUid('alice');
    await tester.pump();
    FlutterError.onError = previous;

    expect(repository.ensureAttempts, hasLength(2));
    expect(repository.ensureCalls, hasLength(1));
    scheduler.releaseNext();
    await tester.pump();
    expect(repository.ensureAttempts, hasLength(2));
    expect(errors, hasLength(1));
  });

  testWidgets('remote settings emission causally refreshes local theme', (
    tester,
  ) async {
    final repository = RecordingProfileRepository();
    final preferences = RecordingThemePreferences('light');
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
          themePreferencesProvider.overrideWithValue(preferences),
        ],
        child: const ProfileLifecycleBindings(
          child: MaterialApp(home: Text('public profile deep-link')),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('public profile deep-link')),
    );
    expect(container.read(themeModeProvider), ThemeMode.light);

    repository.emitSettings(_settings(themeMode: 'dark'));
    await preferences.firstWrite.future;

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(preferences.writes, <String>['dark']);
  });

  testWidgets('remote theme emitted during descendant build is deferred', (
    tester,
  ) async {
    final repository = RecordingProfileRepository();
    final preferences = RecordingThemePreferences('light');
    var emitted = false;
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
          themePreferencesProvider.overrideWithValue(preferences),
        ],
        child: ProfileLifecycleBindings(
          child: MaterialApp(
            home: LayoutBuilder(
              builder: (context, constraints) {
                if (!emitted) {
                  emitted = true;
                  repository.emitSettings(_settings(themeMode: 'dark'));
                }
                return const Text('responsive child');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.text('responsive child')),
    );
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}

UserSettings _settings({required String themeMode}) => UserSettings(
  themeMode: themeMode,
  defaultCollectionView: 'list',
  reducedMotion: false,
  notificationsEnabled: true,
  profileVisibility: 'private',
  searchable: false,
);

final class RecordingThemePreferences implements ThemePreferences {
  RecordingThemePreferences(this.value);

  String? value;
  final List<String> writes = <String>[];
  final Completer<void> firstWrite = Completer<void>();

  @override
  String? readThemeMode() => value;

  @override
  Future<void> writeThemeMode(String value) async {
    this.value = value;
    writes.add(value);
    if (!firstWrite.isCompleted) firstWrite.complete();
  }
}

final class RecordingProfileRepository implements ProfileRepository {
  final List<OwnerProfileIdentity> ensureCalls = <OwnerProfileIdentity>[];
  final List<OwnerProfileIdentity> ensureAttempts = <OwnerProfileIdentity>[];
  final Completer<void> firstEnsure = Completer<void>();
  final StreamController<UserSettings?> _settings =
      StreamController<UserSettings?>.broadcast(sync: true);
  final StreamController<OwnerProfileIdentity> _ensureAttempts =
      StreamController<OwnerProfileIdentity>.broadcast(sync: true);
  final Map<String, int> ensureFailuresByUid = <String, int>{};
  Completer<void>? nextEnsure;

  Future<OwnerProfileIdentity> get nextEnsureAttempt =>
      _ensureAttempts.stream.first;

  void emitSettings(UserSettings settings) => _settings.add(settings);

  void dispose() {
    _settings.close();
    _ensureAttempts.close();
  }

  @override
  Future<void> ensureOwnProfile({
    required String uid,
    required String displayName,
  }) async {
    final identity = OwnerProfileIdentity(uid: uid, displayName: displayName);
    ensureAttempts.add(identity);
    _ensureAttempts.add(identity);
    final failuresRemaining = ensureFailuresByUid[uid] ?? 0;
    if (failuresRemaining > 0) {
      ensureFailuresByUid[uid] = failuresRemaining - 1;
      throw StateError('bootstrap failed');
    }
    ensureCalls.add(identity);
    if (!firstEnsure.isCompleted) firstEnsure.complete();
    nextEnsure?.complete();
    nextEnsure = null;
  }

  @override
  Future<PublicProfile?> readPublicProfile(String uid) async => null;

  @override
  Future<List<PublicProfile>> searchPublicProfiles(
    String query, {
    int limit = 20,
  }) async => const <PublicProfile>[];

  @override
  Future<void> updateProfile(String uid, ProfilePatch patch) async {}

  @override
  Future<void> updateDefaultCollectionView(
    String uid,
    String defaultCollectionView,
  ) async {}

  @override
  Future<void> updatePrivacy(String uid, {required bool isPrivate}) async {}

  @override
  Future<void> updateThemeMode(String uid, String themeMode) async {}

  @override
  Stream<UserProfile?> watchOwnProfile(String uid) =>
      Stream<UserProfile?>.value(null);

  @override
  Stream<UserSettings?> watchOwnSettings(String uid) => _settings.stream;

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) =>
      Stream<PublicProfile?>.value(null);
}

final class ManualOwnerBootstrapRetryScheduler
    implements OwnerBootstrapRetryScheduler {
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

final _testUidProvider = NotifierProvider<_TestUidNotifier, String?>(
  _TestUidNotifier.new,
);

final class _TestUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void setUid(String? uid) => state = uid;
}
