import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/gelato_invite.dart';

void main() {
  final now = DateTime(2026, 7, 14, 12);

  Map<String, dynamic> inviteData({String status = 'pending'}) =>
      <String, dynamic>{
        'member_uids': <String>['alice', 'bob'],
        'sender_id': 'alice',
        'receiver_id': 'bob',
        'status': status,
        'created_at': Timestamp.fromDate(now),
        'responded_at': status == 'pending' ? null : Timestamp.fromDate(now),
      };

  test('parses canonical pending and responded invites', () {
    final pending = GelatoInvite.fromMap(inviteData(), 'invite-1');
    final accepted = GelatoInvite.fromMap(
      inviteData(status: 'accepted'),
      'invite-2',
    );

    expect(pending.status, GelatoInviteStatus.pending);
    expect(pending.respondedAt, isNull);
    expect(accepted.status, GelatoInviteStatus.accepted);
    expect(accepted.respondedAt, now);
  });

  test('rejects mismatched sender receiver and members', () {
    final mismatch = inviteData()
      ..['member_uids'] = <String>['alice', 'charlie'];
    expect(
      () => GelatoInvite.fromMap(mismatch, 'invite-1'),
      throwsA(isA<FormatException>()),
    );

    final selfInvite = inviteData()..['receiver_id'] = 'alice';
    expect(
      () => GelatoInvite.fromMap(selfInvite, 'invite-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid states and unsafe response timestamps', () {
    final unknownState = inviteData()..['status'] = 'expired';
    expect(
      () => GelatoInvite.fromMap(unknownState, 'invite-1'),
      throwsA(isA<FormatException>()),
    );

    final pendingWithResponse = inviteData()
      ..['responded_at'] = Timestamp.fromDate(now);
    expect(
      () => GelatoInvite.fromMap(pendingWithResponse, 'invite-1'),
      throwsA(isA<FormatException>()),
    );

    final acceptedWithoutResponse = inviteData(status: 'accepted')
      ..['responded_at'] = null;
    expect(
      () => GelatoInvite.fromMap(acceptedWithoutResponse, 'invite-1'),
      throwsA(isA<FormatException>()),
    );

    final unsafeTimestamp = inviteData()..['created_at'] = '2026-07-14';
    expect(
      () => GelatoInvite.fromMap(unsafeTimestamp, 'invite-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects fields outside the server-owned projection', () {
    final extra = inviteData()..['sender_name'] = 'Alice';
    expect(
      () => GelatoInvite.fromMap(extra, 'invite-1'),
      throwsA(isA<FormatException>()),
    );
  });
}
