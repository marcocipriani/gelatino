import 'firestore_parsing.dart';

enum GelatoInviteStatus { pending, accepted, declined }

class GelatoInvite {
  const GelatoInvite._({
    required this.id,
    required this.memberUids,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  final String id;
  final List<String> memberUids;
  final String senderId;
  final String receiverId;
  final GelatoInviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  factory GelatoInvite.fromMap(Map<String, dynamic> data, String documentId) {
    _requireExactKeys(data, _gelatoInviteKeys, 'gelato invite');
    _requireId(documentId, 'document id');
    final members = stringList(data, 'member_uids');
    final senderId = requireString(data, 'sender_id');
    final receiverId = requireString(data, 'receiver_id');
    _requireId(senderId, 'sender_id');
    _requireId(receiverId, 'receiver_id');
    if (senderId == receiverId ||
        members.length != 2 ||
        members.toSet().length != 2 ||
        !members.contains(senderId) ||
        !members.contains(receiverId)) {
      throw const FormatException(
        'member_uids: must contain distinct sender and receiver',
      );
    }

    final status = _parseStatus(requireString(data, 'status'));
    final respondedAt = optionalTimestamp(data, 'responded_at');
    if ((status == GelatoInviteStatus.pending && respondedAt != null) ||
        (status != GelatoInviteStatus.pending && respondedAt == null)) {
      throw FormatException('${status.name}: invalid responded_at');
    }

    return GelatoInvite._(
      id: documentId,
      memberUids: members,
      senderId: senderId,
      receiverId: receiverId,
      status: status,
      createdAt: requireTimestamp(data, 'created_at'),
      respondedAt: respondedAt,
    );
  }
}

const Set<String> _gelatoInviteKeys = <String>{
  'member_uids',
  'sender_id',
  'receiver_id',
  'status',
  'created_at',
  'responded_at',
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

GelatoInviteStatus _parseStatus(String value) {
  for (final status in GelatoInviteStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('status: invalid value $value');
}

final RegExp _validId = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');

void _requireId(String value, String label) {
  if (!_validId.hasMatch(value)) throw FormatException('$label: invalid ID');
}
