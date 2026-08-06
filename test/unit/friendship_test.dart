import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/friendship.dart';

void main() {
  final now = DateTime(2026, 7, 14, 12);

  Map<String, dynamic> friendshipData({String state = 'pending'}) =>
      <String, dynamic>{
        'member_uids': <String>['alice', 'bob'],
        'requester_uid': 'alice',
        'recipient_uid': 'bob',
        'state': state,
        'requested_at': Timestamp.fromDate(now),
        'responded_at': state == 'pending' ? null : Timestamp.fromDate(now),
        'accepted_at': state == 'accepted' || state == 'removed'
            ? Timestamp.fromDate(now)
            : null,
        'removed_at': state == 'removed' ? Timestamp.fromDate(now) : null,
        'affinity_score': 7,
        'updated_at': Timestamp.fromDate(now),
      };

  test('parses a canonical friendship for a member', () {
    final friendship = Friendship.fromMap(
      friendshipData(state: 'accepted'),
      'YWxpY2U.Ym9i',
      callerUid: 'alice',
    );

    expect(friendship.memberUids, <String>['alice', 'bob']);
    expect(friendship.state, FriendshipState.accepted);
    expect(friendship.affinityScore, 7);
  });

  test('rejects a caller outside member_uids', () {
    expect(
      () => Friendship.fromMap(
        friendshipData(),
        'YWxpY2U.Ym9i',
        callerUid: 'charlie',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects noncanonical pair and participant relationships', () {
    expect(
      () => Friendship.fromMap(
        friendshipData(),
        'wrong-pair',
        callerUid: 'alice',
      ),
      throwsA(isA<FormatException>()),
    );

    final duplicateMembers = friendshipData()
      ..['member_uids'] = <String>['alice', 'alice'];
    expect(
      () => Friendship.fromMap(
        duplicateMembers,
        'YWxpY2U.Ym9i',
        callerUid: 'alice',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid state and timestamp combinations', () {
    final pendingWithResponse = friendshipData()
      ..['responded_at'] = Timestamp.fromDate(now);
    expect(
      () => Friendship.fromMap(
        pendingWithResponse,
        'YWxpY2U.Ym9i',
        callerUid: 'alice',
      ),
      throwsA(isA<FormatException>()),
    );

    final unsafeTimestamp = friendshipData()..['updated_at'] = 0;
    expect(
      () => Friendship.fromMap(
        unsafeTimestamp,
        'YWxpY2U.Ym9i',
        callerUid: 'alice',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects fields outside the server-owned projection', () {
    final extra = friendshipData()..['client_note'] = 'not allowed';
    expect(
      () => Friendship.fromMap(extra, 'YWxpY2U.Ym9i', callerUid: 'alice'),
      throwsA(isA<FormatException>()),
    );
  });
}
