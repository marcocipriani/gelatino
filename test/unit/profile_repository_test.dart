import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/repositories/profile_repository.dart';

void main() {
  group('ProfileRepository', () {
    late FakeProfileDataSource source;
    late ProfileRepository repository;

    setUp(() {
      source = FakeProfileDataSource();
      repository = ProfileRepositoryImpl(source);
    });

    test('owner and social streams use their exact document paths', () async {
      source.documents['users/alice'] = ProfileDocument(
        id: 'alice',
        data: _ownerData(points: 7),
      );
      source.documents['public_profiles/bob'] = ProfileDocument(
        id: 'bob',
        data: _publicData('bob'),
      );

      final owner = await repository.watchOwnProfile('alice').first;
      final social = await repository.watchPublicProfile('bob').first;

      expect(owner?.uid, 'alice');
      expect(owner?.points, 7);
      expect(social?.uid, 'bob');
      expect(source.watchedPaths, ['users/alice', 'public_profiles/bob']);
    });

    test(
      'every UID boundary fails fast before touching the data source',
      () async {
        for (final uid in <String>[
          '',
          'alice/bob',
          'alice\n',
          List<String>.filled(129, 'a').join(),
        ]) {
          expect(
            () => repository.watchOwnProfile(uid),
            throwsA(isA<FormatException>()),
            reason: 'watchOwnProfile $uid',
          );
          expect(
            () => repository.watchOwnSettings(uid),
            throwsA(isA<FormatException>()),
            reason: 'watchOwnSettings $uid',
          );
          expect(
            () => repository.watchPublicProfile(uid),
            throwsA(isA<FormatException>()),
            reason: 'watchPublicProfile $uid',
          );
          await expectLater(
            repository.readPublicProfile(uid),
            throwsA(isA<FormatException>()),
            reason: 'readPublicProfile $uid',
          );
          expect(
            () => repository.ensureOwnProfile(uid: uid, displayName: 'Alice'),
            throwsA(isA<FormatException>()),
            reason: 'ensureOwnProfile $uid',
          );
          await expectLater(
            repository.updateProfile(
              uid,
              const ProfilePatch(displayName: 'Alice'),
            ),
            throwsA(isA<FormatException>()),
            reason: 'updateProfile $uid',
          );
          expect(
            () => repository.updateThemeMode(uid, 'dark'),
            throwsA(isA<FormatException>()),
            reason: 'updateThemeMode $uid',
          );
          expect(
            () => repository.updateDefaultCollectionView(uid, 'map'),
            throwsA(isA<FormatException>()),
            reason: 'updateDefaultCollectionView $uid',
          );
          expect(
            () => repository.updatePrivacy(uid, isPrivate: true),
            throwsA(isA<FormatException>()),
            reason: 'updatePrivacy $uid',
          );
        }

        expect(source.watchedPaths, isEmpty);
        expect(source.readPaths, isEmpty);
        expect(source.createAttempts, 0);
        expect(source.updates, isEmpty);
        expect(source.publicQueries, isEmpty);
      },
    );

    test(
      'initializer is race-safe and writes the exact canonical defaults',
      () async {
        source.synchronizeNextCreatePair();
        await Future.wait([
          repository.ensureOwnProfile(uid: 'alice', displayName: 'Alice'),
          repository.ensureOwnProfile(uid: 'alice', displayName: 'Alice'),
        ]);

        expect(source.createAttempts, 2);
        expect(source.maxConcurrentCreateCalls, 2);
        expect(source.createdDocumentCount, 1);
        expect(source.documents['users/alice']?.data, <String, dynamic>{
          'display_name': 'Alice',
          'username': '',
          'bio': '',
          'city': '',
          'avatar_path': null,
          'favorite_place_id': null,
          'favorite_flavor_id': null,
          'favorite_flavor_ids': <String>[],
          'profile_visibility': 'private',
          'searchable': false,
          'theme_mode': 'system',
          'default_collection_view': 'list',
          'reduced_motion': false,
          'notifications_enabled': true,
          'points': 0,
        });
        expect(
          source.documents['users/alice']!.data,
          isNot(contains('affinity')),
        );
        expect(source.documents['users/alice']!.data, isNot(contains('email')));
        expect(
          source.documents['users/alice']!.data,
          isNot(contains('last_active')),
        );
        expect(
          source.documents['users/alice']!.data,
          isNot(contains('friend_uids')),
        );
        expect(source.documents['users/alice']!.data, isNot(contains('level')));
      },
    );

    test(
      'editable patch emits only allowed fields and explicit deletes',
      () async {
        await repository.updateProfile(
          'alice',
          const ProfilePatch(
            displayName: 'Alice B',
            username: 'aliceb',
            bio: 'Gelato',
            city: 'Roma',
            avatarPath: Clear<String>(),
            favoritePlaceId: Clear<String>(),
            favoriteFlavorId: SetValue<String>('pistacchio'),
            favoriteFlavorIds: <String>['pistacchio'],
          ),
        );

        final update = source.updates.single;
        expect(update.$1, 'users/alice');
        expect(update.$2.keys, <String>{
          'display_name',
          'username',
          'bio',
          'city',
          'avatar_path',
          'favorite_place_id',
          'favorite_flavor_id',
          'favorite_flavor_ids',
        });
        expect(update.$2['avatar_path'], isA<ProfileDelete>());
        expect(update.$2['favorite_place_id'], isA<ProfileDelete>());
        expect(update.$2['favorite_flavor_id'], 'pistacchio');
        expect(update.$2, isNot(contains('points')));
        expect(update.$2, isNot(contains('theme_mode')));
        expect(update.$2, isNot(contains('friend_uids')));
        expect(update.$2, isNot(contains('affinity')));
      },
    );

    test('profile patch rejects unsafe canonical avatar paths', () async {
      await repository.updateProfile(
        'alice',
        const ProfilePatch(
          avatarPath: SetValue<String>('avatars/alice/profile.jpg'),
        ),
      );
      expect(
        source.updates.single.$2['avatar_path'],
        'avatars/alice/profile.jpg',
      );

      for (final path in <String>[
        '',
        '/avatars/alice.jpg',
        'https://example.test/alice.jpg',
        'gs://bucket/alice.jpg',
        'avatars/alice/../bob.jpg',
        'avatars/alice\n.jpg',
      ]) {
        await expectLater(
          repository.updateProfile(
            'alice',
            ProfilePatch(avatarPath: SetValue<String>(path)),
          ),
          throwsA(isA<FormatException>()),
          reason: path,
        );
      }
      expect(source.updates, hasLength(1));
    });

    test(
      'own and public parsing reject unsafe canonical avatar paths',
      () async {
        final errors = _captureFlutterErrors();
        for (final path in <String>[
          '/avatars/alice.jpg',
          'https://example.test/alice.jpg',
          'custom:avatar.jpg',
          'avatars/alice\u0000.jpg',
        ]) {
          source.documents['users/alice'] = ProfileDocument(
            id: 'alice',
            data: _ownerData()..['avatar_path'] = path,
          );
          source.documents['public_profiles/alice'] = ProfileDocument(
            id: 'alice',
            data: _publicData('alice')..['avatar_path'] = path,
          );

          expect(await repository.watchOwnProfile('alice').first, isNull);
          expect(await repository.watchPublicProfile('alice').first, isNull);
        }

        expect(errors, hasLength(8));
      },
    );

    test(
      'settings read and atomic updates touch only their exact keys',
      () async {
        source.documents['users/alice'] = ProfileDocument(
          id: 'alice',
          data: _ownerData(themeMode: 'dark', defaultCollectionView: 'map'),
        );

        final settings = await repository.watchOwnSettings('alice').first;
        expect(settings?.themeMode, 'dark');
        expect(settings?.defaultCollectionView, 'map');

        await repository.updateThemeMode('alice', 'light');
        await repository.updateDefaultCollectionView('alice', 'list');
        await repository.updatePrivacy('alice', isPrivate: false);
        await repository.updatePrivacy('alice', isPrivate: true);

        expect(source.updates, hasLength(4));
        expect(
          source.updates.map((update) => update.$1),
          everyElement('users/alice'),
        );
        expect(source.updates[0].$2, <String, Object?>{'theme_mode': 'light'});
        expect(source.updates[1].$2, <String, Object?>{
          'default_collection_view': 'list',
        });
        expect(source.updates[2].$2, <String, Object?>{
          'profile_visibility': 'public',
          'searchable': true,
        });
        expect(source.updates[3].$2, <String, Object?>{
          'profile_visibility': 'private',
          'searchable': false,
        });
      },
    );

    test(
      'invalid default view falls back without write-back and is reported',
      () async {
        final errors = _captureFlutterErrors();
        source.documents['users/alice'] = ProfileDocument(
          id: 'alice',
          data: _ownerData(
            themeMode: 'dark',
            defaultCollectionView: 'grid',
            notificationsEnabled: false,
          ),
        );

        final settings = await repository.watchOwnSettings('alice').first;

        expect(settings?.defaultCollectionView, 'list');
        expect(settings?.themeMode, 'dark');
        expect(settings?.notificationsEnabled, isFalse);
        expect(source.updates, isEmpty);
        expect(errors, hasLength(1));
        expect(
          errors.single.exceptionAsString(),
          contains('default_collection_view'),
        );
      },
    );

    test('search below two normalized characters performs no read', () async {
      expect(await repository.searchPublicProfiles(' A '), isEmpty);
      expect(source.publicQueries, isEmpty);
      expect(source.readPaths, isEmpty);
      expect(source.watchedPaths, isEmpty);
    });

    test(
      'search executes exactly both bounded public prefix queries',
      () async {
        source.queryResults['username_lower'] = [
          ProfileDocument(id: 'alice', data: _publicData('alice')),
        ];
        source.queryResults['display_name_lower'] = [
          ProfileDocument(id: 'alina', data: _publicData('alina')),
        ];

        await repository.searchPublicProfiles('  AL  ');

        expect(source.publicQueries, hasLength(2));
        expect(
          source.publicQueries.map((query) => query.orderByField),
          <String>['username_lower', 'display_name_lower'],
        );
        for (final query in source.publicQueries) {
          expect(query.collectionPath, 'public_profiles');
          expect(query.searchable, isTrue);
          expect(query.profileVisibility, 'public');
          expect(query.startAt, 'al');
          expect(query.endAt, 'al\uf8ff');
          expect(query.limit, 20);
        }
        expect(source.readPaths, isEmpty);
        expect(source.watchedPaths, isEmpty);
      },
    );

    test(
      'search merges, deduplicates, sorts and caps deterministically at 20',
      () async {
        source.queryResults['username_lower'] = [
          for (var index = 0; index < 15; index++)
            ProfileDocument(
              id: 'user-${index.toString().padLeft(2, '0')}',
              data: _publicData('user-${index.toString().padLeft(2, '0')}'),
            ),
        ];
        source.queryResults['display_name_lower'] = [
          for (var index = 10; index < 30; index++)
            ProfileDocument(
              id: 'user-${index.toString().padLeft(2, '0')}',
              data: _publicData('user-${index.toString().padLeft(2, '0')}'),
            ),
        ];

        final results = await repository.searchPublicProfiles('us');

        expect(results, hasLength(20));
        expect(results.map((profile) => profile.uid).toSet(), hasLength(20));
        expect(results.first.uid, 'user-00');
        expect(results.last.uid, 'user-19');
      },
    );

    test(
      'malformed profile/settings/public streams report and keep running',
      () async {
        final errors = _captureFlutterErrors();
        source.streamDocuments['users/alice'] = [
          const ProfileDocument(
            id: 'alice',
            data: {'points': 'bad', 'theme_mode': 7},
          ),
          ProfileDocument(id: 'alice', data: _ownerData()),
        ];
        source.streamDocuments['public_profiles/bob'] = [
          const ProfileDocument(id: 'bob', data: {'uid': 'bob'}),
          ProfileDocument(id: 'bob', data: _publicData('bob')),
        ];

        final profiles = await repository
            .watchOwnProfile('alice')
            .take(2)
            .toList();
        final settings = await repository
            .watchOwnSettings('alice')
            .take(2)
            .toList();
        final publicProfiles = await repository
            .watchPublicProfile('bob')
            .take(2)
            .toList();

        expect(profiles, [isNull, isNotNull]);
        expect(settings, [isNull, isNotNull]);
        expect(publicProfiles, [isNull, isNotNull]);
        expect(errors, hasLength(3));
      },
    );

    test('malformed public search result is reported and dropped', () async {
      final errors = _captureFlutterErrors();
      source.queryResults['username_lower'] = const [
        ProfileDocument(id: 'broken', data: {'uid': 'broken'}),
      ];
      source.queryResults['display_name_lower'] = [
        ProfileDocument(id: 'alice', data: _publicData('alice')),
      ];

      final results = await repository.searchPublicProfiles('al');

      expect(results.map((profile) => profile.uid), ['alice']);
      expect(errors, hasLength(1));
    });
  });

  test(
    'owner profile and settings providers are pure readers when document is absent',
    () async {
      final source = FakeProfileDataSource();
      final repository = ProfileRepositoryImpl(source);
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final profileSubscription = container.listen(
        ownProfileProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      final settingsSubscription = container.listen(
        ownSettingsProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(profileSubscription.close);
      addTearDown(settingsSubscription.close);

      expect(await container.read(ownProfileProvider.future), isNull);
      expect(await container.read(ownSettingsProvider.future), isNull);
      expect(source.createdDocumentCount, 0);
    },
  );

  test(
    'providers derive owner state, settings and server points from auth',
    () async {
      final source = FakeProfileDataSource()
        ..documents['users/alice'] = ProfileDocument(
          id: 'alice',
          data: _ownerData(points: 42, defaultCollectionView: 'map'),
        );
      final repository = ProfileRepositoryImpl(source);
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          currentUserDisplayNameProvider.overrideWithValue('Alice'),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final profileSubscription = container.listen(
        ownProfileProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      final settingsSubscription = container.listen(
        ownSettingsProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(profileSubscription.close);
      addTearDown(settingsSubscription.close);

      expect((await container.read(ownProfileProvider.future))?.uid, 'alice');
      expect(
        (await container.read(
          ownSettingsProvider.future,
        ))?.defaultCollectionView,
        'map',
      );
      await container.pump();
      expect(container.read(serverPointsProvider), 42);

      container.updateOverrides([
        currentUidProvider.overrideWithValue(null),
        currentUserDisplayNameProvider.overrideWithValue('Alice'),
        profileRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();

      expect(await container.read(ownProfileProvider.future), isNull);
      expect(await container.read(ownSettingsProvider.future), isNull);
      expect(container.read(serverPointsProvider), isNull);
    },
  );

  test(
    'Task 3 source contains no private/global user reads or legacy writes',
    () {
      final source = File(
        'lib/providers/user_provider.dart',
      ).readAsStringSync();
      final main = File('lib/screens/main_screen.dart').readAsStringSync();

      expect(source, isNot(contains("collection('users').get()")));
      expect(source, isNot(contains("collection('users').doc(userId)")));
      expect(source, isNot(contains('FieldValue.arrayUnion')));
      expect(source, isNot(contains('FieldValue.arrayRemove')));
      expect(source, isNot(contains('updateProfile(UserProfile')));
      expect(source, isNot(contains("'affinity'")));
      expect(source, isNot(contains("'last_active'")));
      expect(main, isNot(contains("'last_active'")));
    },
  );
}

List<FlutterErrorDetails> _captureFlutterErrors() {
  final previous = FlutterError.onError;
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

Map<String, dynamic> _ownerData({
  int points = 0,
  String themeMode = 'system',
  String defaultCollectionView = 'list',
  bool notificationsEnabled = true,
}) => <String, dynamic>{
  'display_name': 'Alice',
  'username': 'alice',
  'bio': '',
  'city': 'Roma',
  'avatar_path': null,
  'favorite_place_id': null,
  'favorite_flavor_id': null,
  'favorite_flavor_ids': <String>[],
  'profile_visibility': 'private',
  'searchable': false,
  'theme_mode': themeMode,
  'default_collection_view': defaultCollectionView,
  'reduced_motion': false,
  'notifications_enabled': notificationsEnabled,
  'points': points,
};

Map<String, dynamic> _publicData(String uid) => <String, dynamic>{
  'uid': uid,
  'display_name': uid,
  'display_name_lower': uid.toLowerCase(),
  'username': uid,
  'username_lower': uid.toLowerCase(),
  'avatar_path': null,
  'bio': '',
  'city': 'Roma',
  'favorite_place_id': null,
  'favorite_flavor_id': null,
  'favorite_flavor_ids': <String>[],
  'profile_visibility': 'public',
  'searchable': true,
  'points': 0,
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
};

final class FakeProfileDataSource implements ProfileDataSource {
  final Map<String, ProfileDocument> documents = {};
  final Map<String, List<ProfileDocument?>> streamDocuments = {};
  final Map<String, List<ProfileDocument>> queryResults = {};
  final List<String> watchedPaths = [];
  final List<String> readPaths = [];
  final List<PublicProfilePrefixQuery> publicQueries = [];
  final List<(String, Map<String, Object?>)> updates = [];
  int createdDocumentCount = 0;
  int createAttempts = 0;
  int maxConcurrentCreateCalls = 0;
  int _concurrentCreateCalls = 0;
  Completer<void>? _createPairBarrier;

  void synchronizeNextCreatePair() {
    _createPairBarrier = Completer<void>();
  }

  @override
  Stream<ProfileDocument?> watchDocument(String path) {
    watchedPaths.add(path);
    return Stream<ProfileDocument?>.fromIterable(
      streamDocuments[path] ?? <ProfileDocument?>[documents[path]],
    );
  }

  @override
  Future<ProfileDocument?> readDocument(String path) async {
    readPaths.add(path);
    return documents[path];
  }

  @override
  Future<void> createDocumentIfAbsent(
    String path,
    Map<String, Object?> data,
  ) async {
    createAttempts++;
    _concurrentCreateCalls++;
    if (_concurrentCreateCalls > maxConcurrentCreateCalls) {
      maxConcurrentCreateCalls = _concurrentCreateCalls;
    }
    try {
      final barrier = _createPairBarrier;
      if (barrier != null) {
        if (_concurrentCreateCalls == 2 && !barrier.isCompleted) {
          barrier.complete();
        }
        await barrier.future;
      }
      if (documents.containsKey(path)) return;
      documents[path] = ProfileDocument(
        id: path.split('/').last,
        data: Map<String, dynamic>.from(data),
      );
      createdDocumentCount++;
    } finally {
      _concurrentCreateCalls--;
      if (_concurrentCreateCalls == 0) _createPairBarrier = null;
    }
  }

  @override
  Future<void> updateDocument(String path, Map<String, Object?> data) async {
    updates.add((path, Map<String, Object?>.from(data)));
  }

  @override
  Future<List<ProfileDocument>> queryPublicProfiles(
    PublicProfilePrefixQuery query,
  ) async {
    publicQueries.add(query);
    return queryResults[query.orderByField] ?? const <ProfileDocument>[];
  }
}
