import '../../constants/app_strings.dart';

Uri buildExternalInviteUri(String uid) =>
    Uri.https('gelatino.web.app', '/join', <String, String>{'by': uid});

enum FriendSearchRelationshipStatus {
  accepted(false),
  incomingPending(false),
  outgoingPending(false),
  available(true);

  const FriendSearchRelationshipStatus(this.canSendRequest);

  String? get label => switch (this) {
    accepted => AppStrings.relationshipFriend,
    incomingPending => AppStrings.relationshipToAccept,
    outgoingPending => AppStrings.relationshipPending,
    available => AppStrings.add,
  };
  final bool canSendRequest;
}

FriendSearchRelationshipStatus friendSearchRelationshipStatus(
  String candidateUid, {
  required Set<String> acceptedUids,
  required Set<String> incomingPendingUids,
  required Set<String> outgoingPendingUids,
}) {
  if (acceptedUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.accepted;
  }
  if (incomingPendingUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.incomingPending;
  }
  if (outgoingPendingUids.contains(candidateUid)) {
    return FriendSearchRelationshipStatus.outgoingPending;
  }
  return FriendSearchRelationshipStatus.available;
}
