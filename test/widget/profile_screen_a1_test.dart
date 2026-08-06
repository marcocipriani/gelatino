import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/models/flavor.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/flavors_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/theme_provider.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/screens/profile/profile_relationship_action.dart';
import 'package:gelatino/screens/profile_screen.dart';

final _testAuthUidProvider = NotifierProvider<_TestAuthUid, String?>(
  _TestAuthUid.new,
);
final _testTargetUidProvider = NotifierProvider<_TestTargetUid, String>(
  _TestTargetUid.new,
);

void main() {
  testWidgets(
    'Profile uses compact medium and wide A1 geometry without 200% overflow',
    (tester) async {
      for (final testCase in <({double width, String layout})>[
        (width: 390, layout: 'compact'),
        (width: 768, layout: 'medium'),
        (width: 1024, layout: 'medium'),
        (width: 1440, layout: 'wide'),
      ]) {
        tester.view.physicalSize = Size(testCase.width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _profileHarness(
            textScale: 2,
            relationships: AsyncData<List<Friendship>>(<Friendship>[
              _friendship(
                requester: 'alice',
                recipient: 'bob',
                state: FriendshipState.accepted,
              ),
            ]),
            history: AsyncData<List<FeedItem>>(<FeedItem>[
              _feed('bob', 4, placeName: 'Gelateria E2E'),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('profile-${testCase.layout}')),
          findsOneWidget,
        );
        expect(find.text('Bob pubblico'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Profile honors narrow constraints inside a wide MediaQuery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(_profileHarness(constrainedWidth: 390));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-compact')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-wide')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public profile reads only public data and no owner controls', (
    tester,
  ) async {
    final probe = _ProfileProbe();
    await tester.pumpWidget(
      _profileHarness(
        probe: probe,
        history: AsyncData<List<FeedItem>>(<FeedItem>[_feed('bob', 4)]),
      ),
    );
    await tester.pumpAndSettle();

    expect(probe.ownProfileReads, 0);
    expect(probe.ownSettingsReads, 0);
    expect(probe.publicProfileReads, <String>['bob']);
    expect(probe.historyReads, <String>['bob']);
    expect(find.text('alice@example.com'), findsNothing);
    expect(find.text('Modifica Profilo'), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.text('Vista Default Gelaterie'), findsNothing);
    expect(find.text('Vista Default'), findsNothing);
    expect(find.text('Tema App'), findsNothing);
    expect(find.byTooltip('Indietro'), findsOneWidget);
    expect(_keysStartingWith('profile-delete-'), findsNothing);
    expect(_keysStartingWith('profile-remove-'), findsNothing);
  });

  testWidgets('public relationship exposes reciprocal states and actions', (
    tester,
  ) async {
    final cases =
        <({List<Friendship> relationships, String label, String? actionKey})>[
          (
            relationships: <Friendship>[
              _friendship(
                requester: 'alice',
                recipient: 'bob',
                state: FriendshipState.accepted,
              ),
            ],
            label: 'Amico',
            actionKey: 'profile-relationship-remove-bob',
          ),
          (
            relationships: <Friendship>[
              _friendship(requester: 'bob', recipient: 'alice'),
            ],
            label: 'Da accettare',
            actionKey: 'profile-relationship-accept-bob',
          ),
          (
            relationships: <Friendship>[
              _friendship(requester: 'alice', recipient: 'bob'),
            ],
            label: 'In attesa',
            actionKey: null,
          ),
          (
            relationships: const <Friendship>[],
            label: 'Aggiungi',
            actionKey: 'profile-relationship-send-bob',
          ),
        ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        _profileHarness(
          key: UniqueKey(),
          relationships: AsyncData<List<Friendship>>(testCase.relationships),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(testCase.label), findsWidgets);
      if (testCase.actionKey case final key?) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    }
  });

  testWidgets(
    'relationship send is single-flight and ignores stale target UID',
    (tester) async {
      final repository = _ActionFriendships()..sendGate = Completer<void>();
      await tester.pumpWidget(_dynamicProfileHarness(friendships: repository));
      await tester.pumpAndSettle();

      final send = tester.widget<FilledButton>(
        find.byKey(const ValueKey('profile-relationship-send-bob')),
      );
      send.onPressed!();
      send.onPressed!();
      await tester.pump();
      expect(repository.sendCalls, <String>['bob']);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
      container.read(_testTargetUidProvider.notifier).set('carol');
      container.read(_testAuthUidProvider.notifier).set('zoe');
      await tester.pump();
      repository.sendGate!.completeError(const FriendshipUnavailableFailure());
      await tester.pumpAndSettle();

      expect(find.text('Carol pubblico'), findsOneWidget);
      expect(find.textContaining('Servizio amicizie'), findsNothing);
      expect(repository.sendCalls, <String>['bob']);
    },
  );

  testWidgets('relationship remove dialog is inert after target changes', (
    tester,
  ) async {
    final repository = _ActionFriendships();
    await tester.pumpWidget(
      _relationshipHarness(
        friendships: repository,
        relationships: <Friendship>[
          _friendship(
            requester: 'alice',
            recipient: 'bob',
            state: FriendshipState.accepted,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('profile-relationship-remove-bob')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileRelationshipAction)),
    );
    container.read(_testTargetUidProvider.notifier).set('carol');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rimuovi'));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, isEmpty);
    expect(
      find.byKey(const ValueKey('profile-relationship-send-carol')),
      findsOneWidget,
    );
  });

  testWidgets('relationship remove dialog is inert after auth UID changes', (
    tester,
  ) async {
    final repository = _ActionFriendships();
    await tester.pumpWidget(
      _relationshipHarness(
        friendships: repository,
        relationships: <Friendship>[
          _friendship(
            requester: 'alice',
            recipient: 'bob',
            state: FriendshipState.accepted,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('profile-relationship-remove-bob')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileRelationshipAction)),
    );
    container.read(_testAuthUidProvider.notifier).set('zoe');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Rimuovi'));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, isEmpty);
  });

  testWidgets('favorite IDs render only live human catalog labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _profileHarness(
        profile: _publicProfile(
          'bob',
          favoriteFlavorId: 'flavor-pistachio',
          favoritePlaceId: 'place-giolitti',
        ),
        flavors: AsyncData<List<Flavor>>(<Flavor>[
          Flavor(id: 'flavor-pistachio', name: 'Pistacchio'),
        ]),
        places: AsyncData<List<Place>>(<Place>[_place()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pistacchio'), findsWidgets);
    expect(find.text('Giolitti'), findsWidgets);
    expect(find.textContaining('flavor-pistachio'), findsNothing);
    expect(find.textContaining('place-giolitti'), findsNothing);
  });

  testWidgets('catalog errors never expose raw favorite IDs', (tester) async {
    await tester.pumpWidget(
      _profileHarness(
        profile: _publicProfile(
          'bob',
          favoriteFlavorId: 'flavor-secret-id',
          favoritePlaceId: 'place-secret-id',
        ),
        flavors: AsyncError<List<Flavor>>(
          StateError('raw flavor backend'),
          StackTrace.current,
        ),
        places: AsyncError<List<Place>>(
          StateError('raw place backend'),
          StackTrace.current,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferenze non disponibili'), findsOneWidget);
    expect(find.textContaining('secret-id'), findsNothing);
    expect(find.textContaining('raw'), findsNothing);
  });

  testWidgets('authorized history drives honest public stats', (tester) async {
    final probe = _ProfileProbe();
    await tester.pumpWidget(
      _profileHarness(
        probe: probe,
        history: AsyncData<List<FeedItem>>(<FeedItem>[
          _feed('bob', 4, placeId: 'place-1'),
          _feed('bob', 2, placeId: 'place-2'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(probe.historyReads, <String>['bob']);
    expect(find.text('2 gelati'), findsOneWidget);
    expect(find.text('2 gelaterie'), findsOneWidget);
    expect(find.text('3.0 media'), findsOneWidget);
    expect(find.text('0 amici'), findsNothing);
  });

  testWidgets('history error is bounded friendly and retries exact source', (
    tester,
  ) async {
    final probe = _ProfileProbe();
    await tester.pumpWidget(
      _profileHarness(
        probe: probe,
        history: AsyncError<List<FeedItem>>(
          StateError('raw history backend'),
          StackTrace.current,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attività non disponibile'), findsOneWidget);
    expect(find.textContaining('raw history'), findsNothing);
    expect(find.text('0 amici'), findsNothing);
    final retry = find.byKey(const ValueKey('profile-history-retry-bob'));
    tester.widget<OutlinedButton>(retry).onPressed!();
    expect(probe.historyRefreshes, <String>['bob']);
  });

  testWidgets('profile loading not-found and error are distinct and friendly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _profileHarness(
        key: UniqueKey(),
        profileValue: const AsyncLoading<PublicProfile?>(),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('profile-loading')), findsOneWidget);

    await tester.pumpWidget(
      _profileHarness(
        key: UniqueKey(),
        profileValue: const AsyncData<PublicProfile?>(null),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profilo non trovato'), findsOneWidget);

    await tester.pumpWidget(
      _profileHarness(
        key: UniqueKey(),
        profileValue: AsyncError<PublicProfile?>(
          StateError('raw profile backend'),
          StackTrace.current,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profilo non disponibile'), findsOneWidget);
    expect(find.textContaining('raw profile'), findsNothing);
    expect(find.byKey(const ValueKey('profile-retry-bob')), findsOneWidget);
  });
}

Finder _keysStartingWith(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

Widget _profileHarness({
  Key? key,
  double textScale = 1,
  double? constrainedWidth,
  PublicProfile? profile,
  AsyncValue<PublicProfile?>? profileValue,
  AsyncValue<List<Friendship>> relationships =
      const AsyncData<List<Friendship>>(<Friendship>[]),
  AsyncValue<List<FeedItem>> history = const AsyncData<List<FeedItem>>(
    <FeedItem>[],
  ),
  AsyncValue<List<Flavor>> flavors = const AsyncData<List<Flavor>>(<Flavor>[]),
  AsyncValue<List<Place>> places = const AsyncData<List<Place>>(<Place>[]),
  FriendshipRepository friendships = const _Friendships(),
  _ProfileProbe? probe,
}) {
  final effectiveProfile = profile ?? _publicProfile('bob');
  final effectiveProfileValue =
      profileValue ?? AsyncData<PublicProfile?>(effectiveProfile);
  final publicStream = _profileStream(effectiveProfileValue);
  final reads = probe ?? _ProfileProbe();
  return ProviderScope(
    key: key,
    overrides: _overrides(
      profileStream: publicStream,
      relationships: relationships,
      history: history,
      flavors: flavors,
      places: places,
      friendships: friendships,
      probe: reads,
    ),
    child: MaterialApp(
      builder: (context, child) {
        final content = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
        if (constrainedWidth == null) return content;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constrainedWidth,
            height: 1000,
            child: content,
          ),
        );
      },
      home: const ProfileScreen(userId: 'bob'),
    ),
  );
}

Widget _dynamicProfileHarness({
  required FriendshipRepository friendships,
  AsyncValue<List<Friendship>> relationships =
      const AsyncData<List<Friendship>>(<Friendship>[]),
}) {
  final probe = _ProfileProbe();
  return ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => ref.watch(_testAuthUidProvider)),
      currentUserProvider.overrideWith((ref) {
        final uid = ref.watch(_testAuthUidProvider);
        return uid == null ? null : _FakeUser(uid);
      }),
      ..._overrides(
        profileStream: null,
        relationships: relationships,
        history: const AsyncData<List<FeedItem>>(<FeedItem>[]),
        flavors: const AsyncData<List<Flavor>>(<Flavor>[]),
        places: const AsyncData<List<Place>>(<Place>[]),
        friendships: friendships,
        probe: probe,
        includeIdentity: false,
      ),
      publicProfileProvider.overrideWith((ref, uid) {
        probe.publicProfileReads.add(uid);
        return Stream<PublicProfile?>.value(_publicProfile(uid));
      }),
    ],
    child: Consumer(
      builder: (context, ref, child) => MaterialApp(
        home: ProfileScreen(userId: ref.watch(_testTargetUidProvider)),
      ),
    ),
  );
}

Widget _relationshipHarness({
  required FriendshipRepository friendships,
  required List<Friendship> relationships,
}) => ProviderScope(
  overrides: [
    currentUidProvider.overrideWith((ref) => ref.watch(_testAuthUidProvider)),
    friendshipRepositoryProvider.overrideWithValue(friendships),
    friendshipsProvider.overrideWithValue(
      AsyncData<List<Friendship>>(relationships),
    ),
    retryFriendshipSourcesProvider.overrideWithValue(() {}),
    publicProfileProvider.overrideWith(
      (ref, uid) => Stream<PublicProfile?>.value(null),
    ),
  ],
  child: Consumer(
    builder: (context, ref, child) => MaterialApp(
      home: Scaffold(
        body: ProfileRelationshipAction(
          targetUid: ref.watch(_testTargetUidProvider),
        ),
      ),
    ),
  ),
);

List<Override> _overrides({
  required Stream<PublicProfile?>? profileStream,
  required AsyncValue<List<Friendship>> relationships,
  required AsyncValue<List<FeedItem>> history,
  required AsyncValue<List<Flavor>> flavors,
  required AsyncValue<List<Place>> places,
  required FriendshipRepository friendships,
  required _ProfileProbe probe,
  bool includeIdentity = true,
}) => <Override>[
  if (includeIdentity) ...[
    currentUserProvider.overrideWithValue(const _FakeUser('alice')),
    currentUidProvider.overrideWithValue('alice'),
  ],
  ownProfileProvider.overrideWith((ref) {
    probe.ownProfileReads++;
    return Stream<UserProfile?>.value(
      UserProfile(uid: 'alice', displayName: 'Alice privata', points: 20),
    );
  }),
  ownSettingsProvider.overrideWith((ref) {
    probe.ownSettingsReads++;
    return Stream.value(null);
  }),
  if (profileStream != null)
    publicProfileProvider.overrideWith((ref, uid) {
      probe.publicProfileReads.add(uid);
      return profileStream;
    }),
  authorizedHistoryProvider.overrideWith((ref, uid) {
    probe.historyReads.add(uid);
    return history;
  }),
  authorizedHistoryRefreshProvider.overrideWith((ref, uid) {
    return () => probe.historyRefreshes.add(uid);
  }),
  friendshipRepositoryProvider.overrideWithValue(friendships),
  friendshipsProvider.overrideWithValue(relationships),
  acceptedFriendsProvider.overrideWithValue(
    const AsyncData<List<String>>(<String>[]),
  ),
  topAffineFriendsProvider.overrideWithValue(
    const AsyncData<List<AffineFriend>>(<AffineFriend>[]),
  ),
  flavorsProvider.overrideWithValue(flavors),
  placesProvider.overrideWithValue(places),
  themePreferencesProvider.overrideWithValue(const _ThemePreferences()),
];

Stream<PublicProfile?> _profileStream(AsyncValue<PublicProfile?> value) {
  return switch (value) {
    AsyncData(:final value) => Stream<PublicProfile?>.value(value),
    AsyncError(:final error, :final stackTrace) => Stream<PublicProfile?>.error(
      error,
      stackTrace,
    ),
    _ => StreamController<PublicProfile?>().stream,
  };
}

final class _ProfileProbe {
  int ownProfileReads = 0;
  int ownSettingsReads = 0;
  final List<String> publicProfileReads = <String>[];
  final List<String> historyReads = <String>[];
  final List<String> historyRefreshes = <String>[];
}

final class _TestAuthUid extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final class _TestTargetUid extends Notifier<String> {
  @override
  String build() => 'bob';

  void set(String value) => state = value;
}

final class _FakeUser implements User {
  const _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => '$uid@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ThemePreferences implements ThemePreferences {
  const _ThemePreferences();

  @override
  String? readThemeMode() => null;

  @override
  Future<void> writeThemeMode(String value) async {}
}

final class _Friendships implements FriendshipRepository {
  const _Friendships();

  @override
  Stream<List<Friendship>> watchForUser(String uid) =>
      Stream<List<Friendship>>.value(const <Friendship>[]);

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async =>
      const <PublicProfile>[];

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => false;

  @override
  Future<void> send(String otherUid) async {}

  @override
  Future<void> respond(String otherUid, FriendResponse response) async {}

  @override
  Future<void> remove(String otherUid) async {}
}

final class _ActionFriendships extends _Friendships {
  final List<String> sendCalls = <String>[];
  final List<String> removeCalls = <String>[];
  Completer<void>? sendGate;

  @override
  Future<void> send(String otherUid) async {
    sendCalls.add(otherUid);
    final gate = sendGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> remove(String otherUid) async {
    removeCalls.add(otherUid);
  }
}

PublicProfile _publicProfile(
  String uid, {
  String? favoriteFlavorId,
  String? favoritePlaceId,
}) => PublicProfile.fromMap(<String, dynamic>{
  'uid': uid,
  'display_name': uid == 'bob' ? 'Bob pubblico' : 'Carol pubblico',
  'display_name_lower': uid,
  'username': uid,
  'username_lower': uid,
  'avatar_path': null,
  'bio': 'Bio pubblica',
  'city': 'Roma',
  'favorite_place_id': favoritePlaceId,
  'favorite_flavor_id': favoriteFlavorId,
  'favorite_flavor_ids': favoriteFlavorId == null
      ? <String>[]
      : <String>[favoriteFlavorId],
  'profile_visibility': 'public',
  'searchable': true,
  'points': 50,
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
}, uid);

Friendship _friendship({
  required String requester,
  required String recipient,
  FriendshipState state = FriendshipState.pending,
}) {
  final members = <String>[requester, recipient]..sort();
  final now = DateTime(2026, 7, 15);
  final accepted = state == FriendshipState.accepted;
  return Friendship.fromMap(
    <String, dynamic>{
      'member_uids': members,
      'requester_uid': requester,
      'recipient_uid': recipient,
      'state': state.name,
      'requested_at': Timestamp.fromDate(now),
      'responded_at': accepted ? Timestamp.fromDate(now) : null,
      'accepted_at': accepted ? Timestamp.fromDate(now) : null,
      'removed_at': null,
      'affinity_score': accepted ? 2 : 0,
      'updated_at': Timestamp.fromDate(now),
    },
    members.map(_encodedId).join('.'),
    callerUid: 'alice',
  );
}

String _encodedId(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

Place _place() => Place(
  id: 'place-giolitti',
  name: 'Giolitti',
  address: 'Roma',
  location: const GeoPoint(41.9, 12.5),
  geohash: 'sr2yk',
  createdAt: DateTime(2026, 7, 15),
);

FeedItem _feed(
  String authorUid,
  int rating, {
  String placeId = 'place-1',
  String? placeName,
}) {
  final id = 'checkin_${placeId}_$rating'.padRight(24, '0');
  return FeedItem.fromMap(<String, dynamic>{
    'author_uid': authorUid,
    'check_in_id': id,
    'user_snapshot': <String, dynamic>{
      'display_name': authorUid,
      'username': authorUid,
      'avatar_path': null,
    },
    'place_id': placeId,
    'place_snapshot': <String, dynamic>{
      'name': placeName ?? placeId,
      'address': 'Roma',
    },
    'gelato_type': <String, dynamic>{'id': 'cono', 'name': 'Cono'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'rating': rating,
    'review_text': '',
    'tagged_user_ids': <String>[],
    'created_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    'photo_storage_path': 'check_ins/$authorUid/$id/photo.jpg',
  }, id);
}
