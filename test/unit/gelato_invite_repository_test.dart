import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/gelato_invite.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/repositories/gelato_invite_repository.dart';
import 'package:gelatino/providers/navigation_provider.dart';

void main() {
  late FakeInviteDataSource source;
  late FakeFriendships friendships;
  late GelatoInviteRepository repository;

  setUp(() {
    source = FakeInviteDataSource();
    friendships = FakeFriendships();
    repository = GelatoInviteRepositoryImpl(source, friendships);
  });

  test(
    'creates exact v2 invite only after accepted-friend preflight',
    () async {
      friendships.accepted = true;
      await repository.send('bob');

      expect(friendships.checks, [('alice', 'bob')]);
      expect(source.creates, hasLength(1));
      expect(source.creates.single, <String, Object?>{
        'member_uids': <String>['alice', 'bob'],
        'sender_id': 'alice',
        'receiver_id': 'bob',
        'status': 'pending',
        'created_at': const InviteServerTimestamp(),
        'responded_at': null,
      });
      expect(source.creates.single, isNot(contains('sender_name')));
    },
  );

  test('a throwing onSent hook does not fail send()', () async {
    friendships.accepted = true;
    final guarded = GelatoInviteRepositoryImpl(
      source,
      friendships,
      () => throw StateError('push hook exploded'),
    );

    await expectLater(guarded.send('bob'), completes);
    expect(source.creates, hasLength(1));
  });

  test('nonfriend and self invite fail before any write', () async {
    await expectLater(
      repository.send('bob'),
      throwsA(isA<InviteFriendshipRequired>()),
    );
    await expectLater(
      repository.send('alice'),
      throwsA(isA<InvalidInviteFailure>()),
    );
    source.authUid = null;
    await expectLater(
      repository.send('bob'),
      throwsA(isA<InviteAuthenticationFailure>()),
    );
    expect(source.creates, isEmpty);
  });

  test(
    'only receiver can respond and writes server response timestamp',
    () async {
      source.documents['invite-1'] = _invite('invite-1');
      source.authUid = 'bob';
      await repository.respond('invite-1', GelatoInviteStatus.accepted);
      expect(source.updates, hasLength(1));
      expect(source.updates.single.$1, 'pings/invite-1');
      expect(source.updates.single.$2, <String, Object?>{
        'status': 'accepted',
        'responded_at': const InviteServerTimestamp(),
      });

      source.authUid = 'alice';
      await expectLater(
        repository.respond('invite-1', GelatoInviteStatus.declined),
        throwsA(isA<InvitePermissionFailure>()),
      );
      expect(source.updates, hasLength(1));
    },
  );

  test('incoming and history queries are constrained ordered and capped', () {
    repository.watchPendingIncoming('alice').listen((_) {});
    repository.watchHistory('alice').listen((_) {});

    final inbox = source.queries[0];
    expect(inbox.collectionPath, 'pings');
    expect(inbox.receiverId, 'alice');
    expect(inbox.status, 'pending');
    expect(inbox.memberUid, isNull);
    expect(inbox.orderByField, 'created_at');
    expect(inbox.descending, isTrue);
    expect(inbox.limit, 50);

    final history = source.queries[1];
    expect(history.collectionPath, 'pings');
    expect(history.memberUid, 'alice');
    expect(history.receiverId, isNull);
    expect(history.status, isNull);
    expect(history.orderByField, 'created_at');
    expect(history.descending, isTrue);
    expect(history.limit, 100);
  });

  test('malformed incoming invite is reported and skipped', () async {
    final errors = _captureFlutterErrors();
    final done = Completer<List<GelatoInvite>>();
    final subscription = repository
        .watchPendingIncoming('bob')
        .listen(done.complete);
    addTearDown(subscription.cancel);
    source.emit(<InviteDocument>[
      _invite('invite-1'),
      const InviteDocument(id: 'bad', data: <String, dynamic>{}),
    ]);

    expect((await done.future).map((invite) => invite.id), ['invite-1']);
    expect(errors, hasLength(1));
  });

  test('accepted invite returns encoded prefill route only', () {
    expect(
      checkInPrefillRoute('alice+one@example.test'),
      '/check-in?prefillFriendId=alice%2Bone%40example.test',
    );
    final navigation = File(
      'lib/providers/navigation_provider.dart',
    ).readAsStringSync();
    expect(navigation, isNot(contains('createCheckIn')));
    expect(navigation, isNot(contains('publish')));
  });

  test('new invite runtime excludes spoofable legacy paths', () {
    for (final path in <String>[
      'lib/repositories/gelato_invite_repository.dart',
      'lib/providers/gelato_invite_providers.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('FirebaseFirestore.instance')),
        reason: path,
      );
      expect(source, isNot(contains('sender_name')), reason: path);
      expect(source, isNot(contains('DateTime.now')), reason: path);
    }
    final repository = File(
      'lib/repositories/gelato_invite_repository.dart',
    ).readAsStringSync();
    expect(repository, isNot(contains('send({required String sender')));
  });
}

final class FakeInviteDataSource implements GelatoInviteDataSource {
  @override
  String? authUid = 'alice';

  final List<GelatoInviteQuery> queries = [];
  final List<Map<String, Object?>> creates = [];
  final List<(String, Map<String, Object?>)> updates = [];
  final Map<String, InviteDocument> documents = {};
  final StreamController<List<InviteDocument>> controller =
      StreamController<List<InviteDocument>>.broadcast(sync: true);

  void emit(List<InviteDocument> documents) => controller.add(documents);

  @override
  Stream<List<InviteDocument>> watchInvites(GelatoInviteQuery query) {
    queries.add(query);
    return controller.stream;
  }

  @override
  Future<void> createInvite(Map<String, Object?> data) async {
    creates.add(Map<String, Object?>.from(data));
  }

  @override
  Future<InviteDocument?> readInvite(String path) async =>
      documents[path.split('/').last];

  @override
  Future<void> updateInvite(String path, Map<String, Object?> data) async {
    updates.add((path, Map<String, Object?>.from(data)));
  }
}

final class FakeFriendships implements FriendshipRepository {
  bool accepted = false;
  final List<(String, String)> checks = [];

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async {
    checks.add((uid, otherUid));
    return accepted;
  }

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async => [];
  @override
  Future<void> remove(String otherUid) async {}
  @override
  Future<void> respond(String otherUid, FriendResponse response) async {}
  @override
  Future<void> send(String otherUid) async {}
  @override
  Stream<List<Friendship>> watchForUser(String uid) => const Stream.empty();
}

InviteDocument _invite(String id) => InviteDocument(
  id: id,
  data: <String, dynamic>{
    'member_uids': <String>['alice', 'bob'],
    'sender_id': 'alice',
    'receiver_id': 'bob',
    'status': 'pending',
    'created_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
    'responded_at': null,
  },
);

List<FlutterErrorDetails> _captureFlutterErrors() {
  final previous = FlutterError.onError;
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
