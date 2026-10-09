import '../../constants/app_strings.dart';

Uri buildExternalInviteUri(String uid) =>
    Uri.https('gelatino.web.app', '/join', <String, String>{'by': uid});

enum FriendSearchRelationshipStatus {
  accepted('Amico', false),
  incomingPending(AppStrings.relationshipToAccept, false),
  outgoingPending(AppStrings.relationshipPending, false),
  available(AppStrings.add, true);

  const FriendSearchRelationshipStatus(this.label, this.canSendRequest);

  final String? label;
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
