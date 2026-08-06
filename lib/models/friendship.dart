import 'dart:convert';

import 'firestore_parsing.dart';

enum FriendshipState { pending, accepted, declined, removed }

class Friendship {
  const Friendship._({
    required this.id,
    required this.memberUids,
    required this.requesterUid,
    required this.recipientUid,
    required this.state,
    required this.requestedAt,
    required this.respondedAt,
    required this.acceptedAt,
    required this.removedAt,
    required this.affinityScore,
    required this.updatedAt,
  });

  final String id;
  final List<String> memberUids;
  final String requesterUid;
  final String recipientUid;
  final FriendshipState state;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final DateTime? acceptedAt;
  final DateTime? removedAt;
  final int affinityScore;
  final DateTime updatedAt;

  factory Friendship.fromMap(
    Map<String, dynamic> data,
    String documentId, {
    required String callerUid,
  }) {
    _requireExactKeys(data, _friendshipKeys, 'friendship');
    final members = stringList(data, 'member_uids');
    if (members.length != 2 || members.toSet().length != 2) {
      throw const FormatException('member_uids: expected two unique IDs');
    }
    for (final member in members) {
      _requireId(member, 'member_uids');
    }
    final sortedMembers = [...members]..sort();
    if (!_sameValues(members, sortedMembers)) {
      throw const FormatException('member_uids: must use canonical order');
    }
    if (!members.contains(callerUid)) {
      throw const FormatException('callerUid: not a friendship member');
    }
    final expectedId = sortedMembers.map(_encodeId).join('.');
    if (documentId != expectedId) {
      throw FormatException('document id: expected $expectedId');
    }

    final requesterUid = requireString(data, 'requester_uid');
    final recipientUid = requireString(data, 'recipient_uid');
    if (requesterUid == recipientUid ||
        !members.contains(requesterUid) ||
        !members.contains(recipientUid)) {
      throw const FormatException(
        'requester_uid/recipient_uid: must identify both members',
      );
    }

    final state = _parseState(requireString(data, 'state'));
    final respondedAt = optionalTimestamp(data, 'responded_at');
    final acceptedAt = optionalTimestamp(data, 'accepted_at');
    final removedAt = optionalTimestamp(data, 'removed_at');
    _validateTimestamps(state, respondedAt, acceptedAt, removedAt);

    final affinityScore = requireInt(data, 'affinity_score');
    if (affinityScore < 0) {
      throw const FormatException('affinity_score: must be non-negative');
    }

    return Friendship._(
      id: documentId,
      memberUids: members,
      requesterUid: requesterUid,
      recipientUid: recipientUid,
      state: state,
      requestedAt: requireTimestamp(data, 'requested_at'),
      respondedAt: respondedAt,
      acceptedAt: acceptedAt,
      removedAt: removedAt,
      affinityScore: affinityScore,
      updatedAt: requireTimestamp(data, 'updated_at'),
    );
  }
}

const Set<String> _friendshipKeys = <String>{
  'member_uids',
  'requester_uid',
  'recipient_uid',
  'state',
  'requested_at',
  'responded_at',
  'accepted_at',
  'removed_at',
  'affinity_score',
  'updated_at',
};

void _requireExactKeys(
  Map<String, dynamic> data,
  Set<String> expected,
  String label,
) {
  if (data.length != expected.length ||
      !data.keys.toSet().containsAll(expected)) {
    throw FormatException('$label: invalid fields');
  }
}

FriendshipState _parseState(String value) {
  for (final state in FriendshipState.values) {
    if (state.name == value) return state;
  }
  throw FormatException('state: invalid value $value');
}

void _validateTimestamps(
  FriendshipState state,
  DateTime? respondedAt,
  DateTime? acceptedAt,
  DateTime? removedAt,
) {
  final valid = switch (state) {
    FriendshipState.pending =>
      respondedAt == null && acceptedAt == null && removedAt == null,
    FriendshipState.accepted =>
      respondedAt != null && acceptedAt != null && removedAt == null,
    FriendshipState.declined =>
      respondedAt != null && acceptedAt == null && removedAt == null,
    FriendshipState.removed =>
      respondedAt != null && acceptedAt != null && removedAt != null,
  };
  if (!valid) throw FormatException('${state.name}: invalid timestamps');
}

String _encodeId(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

bool _sameValues(List<String> left, List<String> right) {
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final RegExp _validId = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');

void _requireId(String value, String label) {
  if (!_validId.hasMatch(value)) throw FormatException('$label: invalid ID');
}
