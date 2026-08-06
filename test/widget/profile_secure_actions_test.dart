import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/models/user_settings.dart';
import 'package:gelatino/providers/check_in_providers.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/check_in_repository.dart';
import 'package:gelatino/repositories/timeline_repository.dart';
import 'package:gelatino/screens/profile_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'owner ProfileScreen reads private data and renders owner actions',
    (tester) async {
      final probe = await _pumpProfileScreen(tester);

      expect(probe.ownProfileReads, 1);
      expect(probe.ownSettingsReads, 0);
      expect(probe.publicProfileReads, isEmpty);
      expect(find.text('Alice privata'), findsOneWidget);
      expect(find.text('Modifica Profilo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-settings-gear')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(find.byKey(const ValueKey('profile-default-view')), findsNothing);
      expect(find.byKey(const ValueKey('profile-theme-mode')), findsNothing);
    },
  );

  testWidgets(
    'other ProfileScreen reads exact public data and hides owner actions',
    (tester) async {
      final probe = await _pumpProfileScreen(tester, userId: 'bob');

      expect(probe.ownProfileReads, 0);
      expect(probe.ownSettingsReads, 0);
      expect(probe.publicProfileReads, <String>['bob']);
      expect(find.text('Bob pubblico'), findsOneWidget);
      expect(find.text('Modifica Profilo'), findsNothing);
      expect(find.byKey(const ValueKey('profile-settings-gear')), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(probe.savedPlacesReads, 0);
      expect(find.text('Da provare'), findsNothing);
      expect(find.byKey(const ValueKey('profile-default-view')), findsNothing);
      expect(find.byKey(const ValueKey('profile-theme-mode')), findsNothing);
    },
  );

  testWidgets('owner profile settings gear is latched against double push', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpProfileScreen(tester, router: router);

    final gear = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(const ValueKey('profile-settings-gear')),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!;
    gear();
    gear();
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/profile');
  });

  testWidgets('owner profile keeps settings outside identity and activity', (
    tester,
  ) async {
    final probe = await _pumpProfileScreen(tester, settings: _settings());

    expect(probe.ownSettingsReads, 0);
    expect(find.text('Impostazioni profilo'), findsNothing);
    expect(find.text('Vista Default Gelaterie'), findsNothing);
    expect(find.text('Tema App'), findsNothing);
    expect(find.text('Da provare'), findsOneWidget);
    expect(find.text('Attività recenti'), findsOneWidget);
  });

  testWidgets('owner alone reads and renders saved places with management', (
    tester,
  ) async {
    final probe = await _pumpProfileScreen(
      tester,
      savedPlaces: <Place>[
        _place('place-1', 'Giolitti'),
        _place('place-2', 'Fatamorgana'),
      ],
    );

    expect(probe.savedPlacesReads, 1);
    expect(find.text('Da provare'), findsOneWidget);
    expect(find.text('Giolitti'), findsOneWidget);
    expect(find.text('Fatamorgana'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-remove-place-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-remove-place-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-open-favorite-flavors')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-open-wishlist')), findsOneWidget);
  });

  testWidgets('own history confirms and removes only after delete succeeds', (
    tester,
  ) async {
    final repository = _CheckIns()..gate = Completer<void>();
    final item = _feed('alice');
    await _pumpHistory(
      tester,
      repository: repository,
      item: item,
      canDelete: true,
    );

    await tester.tap(find.byKey(ValueKey('profile-delete-${item.checkInId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pump();

    expect(repository.deletedIds, <String>[item.checkInId]);
    expect(find.text('Giolitti'), findsOneWidget);
    expect(
      find.byKey(ValueKey('profile-delete-pending-${item.checkInId}')),
      findsOneWidget,
    );

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Giolitti'), findsNothing);
  });

  testWidgets('delete failure keeps the item and exposes inline retry', (
    tester,
  ) async {
    final repository = _CheckIns()..failure = const CheckInRetryableFailure();
    final item = _feed('alice');
    await _pumpHistory(
      tester,
      repository: repository,
      item: item,
      canDelete: true,
    );

    await tester.tap(find.byKey(ValueKey('profile-delete-${item.checkInId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(find.text('Giolitti'), findsOneWidget);
    expect(find.textContaining('Pubblicazione interrotta'), findsOneWidget);
    repository.failure = null;
    await tester.tap(
      find.byKey(ValueKey('profile-delete-retry-${item.checkInId}')),
    );
    await tester.pumpAndSettle();
    expect(repository.deletedIds, <String>[item.checkInId, item.checkInId]);
    expect(find.text('Giolitti'), findsNothing);
  });

  testWidgets(
    'successful delete refetches history and stays gone on re-entry',
    (tester) async {
      final checkIns = _CheckIns();
      final item = _feed('alice');
      final history = _HistoryRepository(item);
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          checkInRepositoryProvider.overrideWithValue(checkIns),
          timelineRepositoryProvider.overrideWithValue(history),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _HistoryHarness(historyUid: 'alice'),
        ),
      );
      await tester.pumpAndSettle();
      expect(history.historyCalls, 1);
      expect(find.text('Giolitti'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('profile-delete-${item.checkInId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      expect(checkIns.deletedIds, <String>[item.checkInId]);
      expect(history.historyCalls, 2);
      expect(find.text('Giolitti'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _HistoryHarness(historyUid: 'alice'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Giolitti'), findsNothing);
    },
  );

  testWidgets('failed delete never invalidates authorized history', (
    tester,
  ) async {
    final checkIns = _CheckIns()..failure = const CheckInRetryableFailure();
    final item = _feed('alice');
    final history = _HistoryRepository(item);
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        checkInRepositoryProvider.overrideWithValue(checkIns),
        timelineRepositoryProvider.overrideWithValue(history),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _HistoryHarness(historyUid: 'alice'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('profile-delete-${item.checkInId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(history.historyCalls, 1);
    expect(find.text('Giolitti'), findsOneWidget);
  });

  testWidgets('other-user history never renders a delete control', (
    tester,
  ) async {
    final repository = _CheckIns();
    final item = _feed('bob');
    await _pumpHistory(
      tester,
      repository: repository,
      item: item,
      canDelete: false,
    );

    expect(find.text('Giolitti'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(repository.deletedIds, isEmpty);
  });

  testWidgets(
    'pending history delete cannot mutate or refresh a rebound profile',
    (tester) async {
      final repository = _CheckIns()..gate = Completer<void>();
      final refreshes = <String>[];
      var binding = (
        historyUid: 'alice',
        canDelete: true,
        item: _feed('alice'),
      );
      late StateSetter rebind;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkInRepositoryProvider.overrideWithValue(repository),
            authorizedHistoryRefreshProvider.overrideWith(
              (ref, uid) =>
                  () => refreshes.add(uid),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebind = setState;
                  return ProfileRecentActivityList(
                    historyUid: binding.historyUid,
                    items: <FeedItem>[binding.item],
                    canDelete: binding.canDelete,
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('profile-delete-checkin_1234567890123456')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elimina'));
      await tester.pump();

      rebind(() {
        binding = (
          historyUid: 'carol',
          canDelete: true,
          item: _feed('carol', placeName: 'Fatamorgana'),
        );
      });
      await tester.pump();

      expect(find.text('Fatamorgana'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-delete-checkin_1234567890123456')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('profile-delete-pending-checkin_1234567890123456'),
        ),
        findsNothing,
      );

      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Fatamorgana'), findsOneWidget);
      expect(refreshes, isEmpty);
    },
  );

  testWidgets('delete confirmation becomes inert after owner binding changes', (
    tester,
  ) async {
    final repository = _CheckIns();
    var binding = (historyUid: 'alice', canDelete: true, item: _feed('alice'));
    late StateSetter rebind;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [checkInRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebind = setState;
                return ProfileRecentActivityList(
                  historyUid: binding.historyUid,
                  items: <FeedItem>[binding.item],
                  canDelete: binding.canDelete,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('profile-delete-checkin_1234567890123456')),
    );
    await tester.pumpAndSettle();
    rebind(() {
      binding = (
        historyUid: 'carol',
        canDelete: false,
        item: _feed('carol', placeName: 'Fatamorgana'),
      );
    });
    await tester.pump();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, isEmpty);
    expect(find.text('Fatamorgana'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}

Future<_ProfileProbe> _pumpProfileScreen(
  WidgetTester tester, {
  String? userId,
  UserSettings? settings,
  List<Place> savedPlaces = const <Place>[],
  GoRouter? router,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final probe = _ProfileProbe();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const _FakeUser('alice')),
        currentUidProvider.overrideWithValue('alice'),
        ownProfileProvider.overrideWith((ref) {
          probe.ownProfileReads++;
          return Stream<UserProfile?>.value(
            UserProfile(
              uid: 'alice',
              displayName: 'Alice privata',
              points: 150,
            ),
          );
        }),
        ownSettingsProvider.overrideWith((ref) {
          probe.ownSettingsReads++;
          return Stream.value(settings);
        }),
        publicProfileProvider.overrideWith((ref, uid) {
          probe.publicProfileReads.add(uid);
          return Stream<PublicProfile?>.value(
            uid == 'bob' ? _publicProfile('bob') : null,
          );
        }),
        authorizedHistoryProvider.overrideWith(
          (ref, uid) => const AsyncData<List<FeedItem>>(<FeedItem>[]),
        ),
        friendshipsProvider.overrideWithValue(
          const AsyncData<List<Friendship>>(<Friendship>[]),
        ),
        savedPlacesProvider.overrideWith((ref) {
          probe.savedPlacesReads++;
          return AsyncData<List<Place>>(savedPlaces);
        }),
        placeStateProvider.overrideWith(
          (ref, placeId) => AsyncData<PlaceState?>(
            PlaceState.empty(placeId).copyWith(saved: true),
          ),
        ),
        acceptedFriendsProvider.overrideWithValue(
          const AsyncData<List<String>>(<String>[]),
        ),
        topAffineFriendsProvider.overrideWithValue(
          const AsyncData<List<AffineFriend>>(<AffineFriend>[]),
        ),
      ],
      child: router == null
          ? MaterialApp(home: ProfileScreen(userId: userId))
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return probe;
}

final class _ProfileProbe {
  int ownProfileReads = 0;
  int ownSettingsReads = 0;
  int savedPlacesReads = 0;
  final List<String> publicProfileReads = <String>[];
}

final class _FakeUser implements User {
  const _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => 'alice@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserSettings _settings() => const UserSettings(
  themeMode: 'light',
  defaultCollectionView: 'list',
  reducedMotion: false,
  notificationsEnabled: true,
  profileVisibility: 'private',
  searchable: false,
);

Place _place(String id, String name) => Place(
  id: id,
  name: name,
  address: 'Roma',
  location: const GeoPoint(41.9, 12.5),
  geohash: 'sr2yk',
  createdAt: DateTime(2026, 7, 15),
);

PublicProfile _publicProfile(String uid) =>
    PublicProfile.fromMap(<String, dynamic>{
      'uid': uid,
      'display_name': 'Bob pubblico',
      'display_name_lower': 'bob pubblico',
      'username': 'bob',
      'username_lower': 'bob',
      'avatar_path': null,
      'bio': '',
      'city': 'Roma',
      'favorite_place_id': null,
      'favorite_flavor_id': null,
      'favorite_flavor_ids': <String>[],
      'profile_visibility': 'public',
      'searchable': true,
      'points': 50,
      'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    }, uid);

Future<void> _pumpHistory(
  WidgetTester tester, {
  required _CheckIns repository,
  required FeedItem item,
  required bool canDelete,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [checkInRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: ProfileRecentActivityList(
          historyUid: item.authorUid,
          items: <FeedItem>[item],
          canDelete: canDelete,
        ),
      ),
    ),
  ),
);

class _HistoryHarness extends ConsumerWidget {
  const _HistoryHarness({required this.historyUid});

  final String historyUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(authorizedHistoryProvider(historyUid));
    return MaterialApp(
      home: Scaffold(
        body: history.when(
          data: (items) => ProfileRecentActivityList(
            historyUid: historyUid,
            items: items,
            canDelete: true,
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('$error'),
        ),
      ),
    );
  }
}

FeedItem _feed(String authorUid, {String placeName = 'Giolitti'}) {
  const id = 'checkin_1234567890123456';
  return FeedItem.fromMap(<String, dynamic>{
    'author_uid': authorUid,
    'check_in_id': id,
    'user_snapshot': <String, dynamic>{
      'display_name': authorUid,
      'username': authorUid,
      'avatar_path': null,
    },
    'place_id': 'place-1',
    'place_snapshot': <String, dynamic>{'name': placeName, 'address': 'Roma'},
    'gelato_type': <String, dynamic>{'id': 'cono', 'name': 'Cono'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'rating': 5,
    'review_text': '',
    'tagged_user_ids': <String>[],
    'created_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    'photo_storage_path': 'check_ins/$authorUid/$id/photo.jpg',
  }, id);
}

final class _CheckIns implements CheckInRepository {
  final List<String> deletedIds = <String>[];
  Completer<void>? gate;
  CheckInFailure? failure;

  @override
  Future<void> delete(String checkInId) async {
    deletedIds.add(checkInId);
    if (failure case final value?) throw value;
    if (gate case final value?) await value.future;
  }

  @override
  Future<PublishCheckInResult> publish(CheckInDraft draft) =>
      throw UnimplementedError();
}

final class _HistoryRepository implements TimelineRepository {
  _HistoryRepository(this.initialItem);

  final FeedItem initialItem;
  int historyCalls = 0;

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) async {
    historyCalls++;
    return FeedPage(
      items: historyCalls == 1 ? <FeedItem>[initialItem] : const <FeedItem>[],
      cursor: null,
      hasMore: false,
    );
  }

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20}) =>
      throw UnimplementedError();
}
