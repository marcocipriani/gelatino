import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/gelato_invite.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/repositories/gelato_invite_repository.dart';
import 'package:gelatino/screens/friends_screen.dart';

void main() {
  test('role providers expose accepted, incoming and outgoing only', () async {
    final repository = FakeFriendshipRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        friendshipRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscriptions = [
      container.listen(friendshipsProvider, (_, _) {}, fireImmediately: true),
      container.listen(
        acceptedFriendsProvider,
        (_, _) {},
        fireImmediately: true,
      ),
      container.listen(
        incomingFriendRequestsProvider,
        (_, _) {},
        fireImmediately: true,
      ),
      container.listen(
        outgoingFriendRequestsProvider,
        (_, _) {},
        fireImmediately: true,
      ),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });

    repository.emit(<Friendship>[
      _parse('alice', 'bob', state: 'accepted', affinity: 2),
      _parse('carol', 'alice'),
      _parse('alice', 'dave'),
    ]);
    await container.pump();

    expect(container.read(acceptedFriendsProvider).value, ['bob']);
    expect(
      container
          .read(incomingFriendRequestsProvider)
          .value
          ?.map((item) => item.requesterUid),
      ['carol'],
    );
    expect(
      container
          .read(outgoingFriendRequestsProvider)
          .value
          ?.map((item) => item.recipientUid),
      ['dave'],
    );
  });

  test(
    'sign-out and user switch clear prior user relationship state',
    () async {
      final repository = FakeFriendshipRepository()
        ..profiles = <PublicProfile>[_public('bob')];
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        acceptedFriendsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final profilesSubscription = container.listen(
        acceptedFriendProfilesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final topSubscription = container.listen(
        topAffineFriendsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      addTearDown(profilesSubscription.close);
      addTearDown(topSubscription.close);
      repository.emit([_parse('alice', 'bob', state: 'accepted')]);
      await container.pump();
      expect(container.read(acceptedFriendsProvider).value, ['bob']);
      expect(
        (await container.read(
          acceptedFriendProfilesForUidProvider('alice').future,
        )).map((profile) => profile.uid),
        ['bob'],
      );
      expect(
        (await container.read(
          topAffineFriendsForUidProvider('alice').future,
        )).map((friend) => friend.profile.uid),
        ['bob'],
      );

      container.updateOverrides([
        currentUidProvider.overrideWithValue(null),
        friendshipRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();
      expect(
        container.read(acceptedFriendsProvider).value ?? const <String>[],
        isEmpty,
      );
      expect(
        container.read(acceptedFriendProfilesProvider).value ?? const [],
        isEmpty,
      );
      expect(
        container.read(topAffineFriendsProvider).value ?? const [],
        isEmpty,
      );

      container.updateOverrides([
        currentUidProvider.overrideWithValue('carol'),
        friendshipRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();
      expect(
        container.read(acceptedFriendsProvider).value ?? const <String>[],
        isEmpty,
      );
      expect(
        container.read(acceptedFriendProfilesProvider).value ?? const [],
        isEmpty,
      );
      expect(
        container.read(topAffineFriendsProvider).value ?? const [],
        isEmpty,
      );
      expect(repository.watchedUids, ['alice', 'carol']);
    },
  );

  test(
    'sign-out disposes alice friendship profile and affinity providers',
    () async {
      final repository = FakeFriendshipRepository()
        ..profiles = <PublicProfile>[_public('bob')];
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(friendshipsProvider, (_, _) {}, fireImmediately: true),
        container.listen(
          acceptedFriendProfilesProvider,
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(
          topAffineFriendsProvider,
          (_, _) {},
          fireImmediately: true,
        ),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      repository.emitFor('alice', [_parse('alice', 'bob', state: 'accepted')]);
      await container.pump();
      expect(repository.activeUids, <String>{'alice'});

      container.updateOverrides([
        currentUidProvider.overrideWithValue(null),
        friendshipRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();

      expect(repository.activeUids, isEmpty);
      expect(repository.cancelledUids, contains('alice'));
      expect(container.exists(friendshipsForUidProvider('alice')), isFalse);
      expect(
        container.exists(acceptedFriendProfilesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(topAffineFriendsForUidProvider('alice')),
        isFalse,
      );
    },
  );

  test('top affinity uses canonical friendship scores only', () async {
    final repository = FakeFriendshipRepository()
      ..profiles = <PublicProfile>[_public('bob'), _public('carol')];
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        friendshipRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      topAffineFriendsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    repository.emit(<Friendship>[
      _parse('alice', 'bob', state: 'accepted', affinity: 3),
      _parse('alice', 'carol', state: 'accepted', affinity: 9),
    ]);

    final ranked = await container.read(
      topAffineFriendsForUidProvider('alice').future,
    );
    expect(ranked.map((entry) => (entry.profile.uid, entry.affinityScore)), [
      ('carol', 9),
      ('bob', 3),
    ]);
  });

  test(
    'one-shot accepted profiles waits for pending-first merged prefill',
    () async {
      final source = ProviderFriendshipDataSource()
        ..profileDocuments['bob'] = FriendshipDocument(
          id: 'bob',
          data: _publicData('bob'),
        );
      final repository = FriendshipRepositoryImpl(source);
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        acceptedFriendProfilesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final profilesFuture = container.read(
        acceptedFriendProfilesForUidProvider('alice').future,
      );
      var completed = false;
      unawaited(profilesFuture.then((_) => completed = true));

      source.emit('pending', const <FriendshipDocument>[]);
      await container.pump();
      expect(completed, isFalse);

      source.emit('accepted', <FriendshipDocument>[
        _friendshipDocument('alice', 'bob', state: 'accepted'),
      ]);

      expect((await profilesFuture).map((profile) => profile.uid), ['bob']);
    },
  );

  test('badge sums only incoming pending requests and invites', () {
    final request = _parse('bob', 'alice');
    final invite = GelatoInvite.fromMap(<String, dynamic>{
      'member_uids': <String>['alice', 'bob'],
      'sender_id': 'bob',
      'receiver_id': 'alice',
      'status': 'pending',
      'created_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
      'responded_at': null,
    }, 'invite-1');
    final container = ProviderContainer(
      overrides: [
        incomingFriendRequestsProvider.overrideWithValue(
          AsyncData(<Friendship>[request]),
        ),
        pendingIncomingGelatoInvitesProvider.overrideWithValue(
          AsyncData(<GelatoInvite>[invite]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(friendsBadgeCountProvider), 2);
  });

  test('recent sorting keeps stale hydrated profiles deterministic', () {
    final profiles = <PublicProfile>[_public('carol'), _public('bob')];
    final relationships = <Friendship>[
      _parse('alice', 'bob', state: 'accepted', affinity: 3),
    ];

    final sorted = sortFriendProfilesByRelationshipRecency(
      profiles,
      relationships,
      'alice',
    );

    expect(sorted.map((profile) => profile.uid), ['bob', 'carol']);
  });

  test('search marks incoming pending as non-addable', () {
    final status = friendSearchRelationshipStatus(
      'bob',
      acceptedUids: const <String>{},
      incomingPendingUids: const <String>{'bob'},
      outgoingPendingUids: const <String>{},
    );

    expect(status, FriendSearchRelationshipStatus.incomingPending);
    expect(status.label, 'Da accettare');
    expect(status.canSendRequest, isFalse);
  });

  test(
    'invite provider clears old inbox on sign-out and user switch',
    () async {
      final repository = FakeInviteRepository();
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          gelatoInviteRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        pendingIncomingGelatoInvitesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final historySubscription = container.listen(
        gelatoInviteHistoryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      addTearDown(historySubscription.close);
      repository.emit('alice', <GelatoInvite>[_incomingInvite()]);
      repository.emitHistory('alice', <GelatoInvite>[_incomingInvite()]);
      await container.pump();
      expect(
        container.read(pendingIncomingGelatoInvitesProvider).value,
        hasLength(1),
      );
      expect(container.read(gelatoInviteHistoryProvider).value, hasLength(1));

      container.updateOverrides([
        currentUidProvider.overrideWithValue(null),
        gelatoInviteRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();
      expect(repository.activePendingUids, isEmpty);
      expect(repository.activeHistoryUids, isEmpty);
      expect(repository.cancelledPendingUids, contains('alice'));
      expect(repository.cancelledHistoryUids, contains('alice'));
      expect(
        container.exists(pendingIncomingGelatoInvitesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(gelatoInviteHistoryForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.read(pendingIncomingGelatoInvitesProvider).value ?? const [],
        isEmpty,
      );
      expect(
        container.read(gelatoInviteHistoryProvider).value ?? const [],
        isEmpty,
      );

      container.updateOverrides([
        currentUidProvider.overrideWithValue('carol'),
        gelatoInviteRepositoryProvider.overrideWithValue(repository),
      ]);
      await container.pump();
      expect(
        container.read(pendingIncomingGelatoInvitesProvider).value ?? const [],
        isEmpty,
      );
      expect(
        container.read(gelatoInviteHistoryProvider).value ?? const [],
        isEmpty,
      );
      expect(repository.watchedUids, ['alice', 'carol']);
      expect(repository.historyWatchedUids, ['alice', 'carol']);
    },
  );

  test(
    'user switch cancels alice friendship and invite streams without leaking',
    () async {
      final friendshipRepository = FakeFriendshipRepository()
        ..profiles = <PublicProfile>[_public('bob'), _public('alice')];
      final inviteRepository = FakeInviteRepository();
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(friendshipRepository),
          gelatoInviteRepositoryProvider.overrideWithValue(inviteRepository),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(friendshipsProvider, (_, _) {}, fireImmediately: true),
        container.listen(
          pendingIncomingGelatoInvitesProvider,
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(
          gelatoInviteHistoryProvider,
          (_, _) {},
          fireImmediately: true,
        ),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      friendshipRepository.emitFor('alice', [
        _parse('alice', 'bob', state: 'accepted'),
      ]);
      inviteRepository.emit('alice', <GelatoInvite>[_incomingInvite()]);
      inviteRepository.emitHistory('alice', <GelatoInvite>[_incomingInvite()]);
      await container.pump();

      container.updateOverrides([
        currentUidProvider.overrideWithValue('carol'),
        friendshipRepositoryProvider.overrideWithValue(friendshipRepository),
        gelatoInviteRepositoryProvider.overrideWithValue(inviteRepository),
      ]);
      await container.pump();

      expect(friendshipRepository.activeUids, <String>{'carol'});
      expect(friendshipRepository.cancelledUids, contains('alice'));
      expect(inviteRepository.activePendingUids, <String>{'carol'});
      expect(inviteRepository.activeHistoryUids, <String>{'carol'});
      expect(inviteRepository.cancelledPendingUids, contains('alice'));
      expect(inviteRepository.cancelledHistoryUids, contains('alice'));
      expect(
        container.exists(pendingIncomingGelatoInvitesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(gelatoInviteHistoryForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.read(pendingIncomingGelatoInvitesProvider).value,
        isNull,
      );
      expect(container.read(gelatoInviteHistoryProvider).value, isNull);

      inviteRepository.emit('alice', <GelatoInvite>[_incomingInvite()]);
      inviteRepository.emitHistory('alice', <GelatoInvite>[_incomingInvite()]);
      inviteRepository.emit('carol', const <GelatoInvite>[]);
      inviteRepository.emitHistory('carol', const <GelatoInvite>[]);
      await container.pump();
      expect(
        container.read(pendingIncomingGelatoInvitesProvider).value,
        isEmpty,
      );
      expect(container.read(gelatoInviteHistoryProvider).value, isEmpty);
    },
  );

  test(
    'friendship retry recreates relationship and profile sources then recovers',
    () async {
      final repository = FakeFriendshipRepository()
        ..profiles = <PublicProfile>[_public('bob')]
        ..nextProfileError = StateError('profiles unavailable');
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(
          acceptedFriendsProvider,
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(
          acceptedFriendProfilesProvider,
          (_, _) {},
          fireImmediately: true,
        ),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });

      repository.emit([_parse('alice', 'bob', state: 'accepted')]);
      await container.pump();
      await container.pump();
      expect(repository.profileReadCalls, 1);
      expect(container.read(acceptedFriendProfilesProvider).hasError, isTrue);

      repository.failFor('alice', StateError('friendships unavailable'));
      await container.pump();
      expect(container.read(acceptedFriendsProvider).hasError, isTrue);

      container.read(retryFriendshipSourcesProvider)();
      await container.pump();
      expect(repository.watchedUids, ['alice', 'alice']);

      repository.emit([_parse('alice', 'bob', state: 'accepted')]);
      await container.pump();
      await container.pump();
      expect(repository.profileReadCalls, 2);
      expect(container.read(acceptedFriendsProvider).value, ['bob']);
      expect(
        container
            .read(acceptedFriendProfilesProvider)
            .value
            ?.map((profile) => profile.uid),
        ['bob'],
      );
    },
  );
}

final class FakeFriendshipRepository implements FriendshipRepository {
  final Map<String, StreamController<List<Friendship>>> controllers = {};
  final List<String> watchedUids = [];
  final Set<String> activeUids = {};
  final List<String> cancelledUids = [];
  List<PublicProfile> profiles = const [];
  int profileReadCalls = 0;
  Object? nextProfileError;

  void emit(List<Friendship> relationships) => emitFor('alice', relationships);

  void emitFor(String uid, List<Friendship> relationships) =>
      controllers[uid]!.add(relationships);

  void failFor(String uid, Object error) => controllers[uid]!.addError(error);

  @override
  Stream<List<Friendship>> watchForUser(String uid) {
    watchedUids.add(uid);
    return (controllers[uid] ??= StreamController<List<Friendship>>.broadcast(
      sync: true,
      onListen: () => activeUids.add(uid),
      onCancel: () {
        activeUids.remove(uid);
        cancelledUids.add(uid);
      },
    )).stream;
  }

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async {
    profileReadCalls++;
    final error = nextProfileError;
    nextProfileError = null;
    if (error != null) throw error;
    return profiles.where((profile) => uids.contains(profile.uid)).toList();
  }

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => false;

  @override
  Future<void> remove(String otherUid) async {}

  @override
  Future<void> respond(String otherUid, FriendResponse response) async {}

  @override
  Future<void> send(String otherUid) async {}
}

final class FakeInviteRepository implements GelatoInviteRepository {
  final Map<String, StreamController<List<GelatoInvite>>> controllers = {};
  final Map<String, StreamController<List<GelatoInvite>>> historyControllers =
      {};
  final List<String> watchedUids = [];
  final List<String> historyWatchedUids = [];
  final Set<String> activePendingUids = {};
  final Set<String> activeHistoryUids = {};
  final List<String> cancelledPendingUids = [];
  final List<String> cancelledHistoryUids = [];

  void emit(String uid, List<GelatoInvite> invites) =>
      controllers[uid]!.add(invites);

  void emitHistory(String uid, List<GelatoInvite> invites) =>
      historyControllers[uid]!.add(invites);

  @override
  Stream<List<GelatoInvite>> watchPendingIncoming(String uid) {
    watchedUids.add(uid);
    return (controllers[uid] ??= StreamController.broadcast(
      sync: true,
      onListen: () => activePendingUids.add(uid),
      onCancel: () {
        activePendingUids.remove(uid);
        cancelledPendingUids.add(uid);
      },
    )).stream;
  }

  @override
  Stream<List<GelatoInvite>> watchHistory(String uid) {
    historyWatchedUids.add(uid);
    return (historyControllers[uid] ??=
            StreamController<List<GelatoInvite>>.broadcast(
              sync: true,
              onListen: () => activeHistoryUids.add(uid),
              onCancel: () {
                activeHistoryUids.remove(uid);
                cancelledHistoryUids.add(uid);
              },
            ))
        .stream;
  }

  @override
  Future<void> respond(String inviteId, GelatoInviteStatus response) async {}

  @override
  Future<void> send(String receiverUid) async {}
}

final class ProviderFriendshipDataSource implements FriendshipDataSource {
  final Map<String, StreamController<List<FriendshipDocument>>> controllers =
      {};
  final Map<String, FriendshipDocument> profileDocuments = {};

  void emit(String state, List<FriendshipDocument> documents) =>
      controllers[state]!.add(documents);

  @override
  Stream<List<FriendshipDocument>> watchFriendships(FriendshipQuery query) =>
      (controllers[query.state] ??=
              StreamController<List<FriendshipDocument>>.broadcast(sync: true))
          .stream;

  @override
  Future<List<FriendshipDocument>> readPublicProfiles(
    PublicProfileBatchQuery query,
  ) async => <FriendshipDocument>[
    for (final uid in query.documentIds) ?profileDocuments[uid],
  ];

  @override
  Future<FriendshipDocument?> readFriendship(String path) async => null;

  @override
  Future<Object?> call(String name, Map<String, Object?> payload) async => null;
}

Friendship _parse(
  String sender,
  String receiver, {
  String state = 'pending',
  int affinity = 0,
}) {
  final members = <String>[sender, receiver]..sort();
  final key = members.join('|');
  final id = <String, String>{
    'alice|bob': 'YWxpY2U.Ym9i',
    'alice|carol': 'YWxpY2U.Y2Fyb2w',
    'alice|dave': 'YWxpY2U.ZGF2ZQ',
  }[key]!;
  final time = Timestamp.fromDate(DateTime(2026, 7, 14, 12, affinity));
  return Friendship.fromMap(
    <String, dynamic>{
      'member_uids': members,
      'requester_uid': sender,
      'recipient_uid': receiver,
      'state': state,
      'requested_at': time,
      'responded_at': state == 'pending' ? null : time,
      'accepted_at': state == 'accepted' ? time : null,
      'removed_at': null,
      'affinity_score': affinity,
      'updated_at': time,
    },
    id,
    callerUid: 'alice',
  );
}

PublicProfile _public(String uid) => PublicProfile.fromMap(<String, dynamic>{
  'uid': uid,
  'display_name': uid,
  'display_name_lower': uid,
  'username': uid,
  'username_lower': uid,
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
}, uid);

GelatoInvite _incomingInvite() => GelatoInvite.fromMap(<String, dynamic>{
  'member_uids': <String>['alice', 'bob'],
  'sender_id': 'bob',
  'receiver_id': 'alice',
  'status': 'pending',
  'created_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
  'responded_at': null,
}, 'invite-1');

FriendshipDocument _friendshipDocument(
  String sender,
  String receiver, {
  required String state,
}) {
  final relationship = _parse(sender, receiver, state: state);
  final timestamp = Timestamp.fromDate(relationship.updatedAt);
  return FriendshipDocument(
    id: relationship.id,
    data: <String, dynamic>{
      'member_uids': relationship.memberUids,
      'requester_uid': relationship.requesterUid,
      'recipient_uid': relationship.recipientUid,
      'state': relationship.state.name,
      'requested_at': Timestamp.fromDate(relationship.requestedAt),
      'responded_at': relationship.respondedAt == null
          ? null
          : Timestamp.fromDate(relationship.respondedAt!),
      'accepted_at': relationship.acceptedAt == null
          ? null
          : Timestamp.fromDate(relationship.acceptedAt!),
      'removed_at': relationship.removedAt == null
          ? null
          : Timestamp.fromDate(relationship.removedAt!),
      'affinity_score': relationship.affinityScore,
      'updated_at': timestamp,
    },
  );
}

Map<String, dynamic> _publicData(String uid) => <String, dynamic>{
  'uid': uid,
  'display_name': uid,
  'display_name_lower': uid,
  'username': uid,
  'username_lower': uid,
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
