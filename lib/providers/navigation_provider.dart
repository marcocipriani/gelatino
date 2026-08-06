String checkInPrefillRoute(String senderUid) => Uri(
  path: '/check-in',
  queryParameters: <String, String>{'prefillFriendId': senderUid},
).toString();
