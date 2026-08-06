import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';

/// Migration-only adapter for pre-Task-5 social arrays on place documents.
final class LegacyPlaceSocialState {
  LegacyPlaceSocialState({
    required this.placeId,
    required List<String> likedByUids,
    required List<String> favoritedByUids,
    required List<String> wishlistedByUids,
  }) : likedByUids = List<String>.unmodifiable(likedByUids),
       favoritedByUids = List<String>.unmodifiable(favoritedByUids),
       wishlistedByUids = List<String>.unmodifiable(wishlistedByUids);

  final String placeId;
  final List<String> likedByUids;
  final List<String> favoritedByUids;
  final List<String> wishlistedByUids;

  factory LegacyPlaceSocialState.fromFirestore(DocumentSnapshot document) {
    requirePathSegment(document.id, 'document id');
    final value = document.data();
    if (value is! Map<String, dynamic>) {
      throw const FormatException('document: expected Map<String, dynamic>');
    }
    return LegacyPlaceSocialState(
      placeId: document.id,
      likedByUids: _arrayOrEmpty(value, 'liked_by_uids'),
      favoritedByUids: _arrayOrEmpty(value, 'favorited_by_uids'),
      wishlistedByUids: _arrayOrEmpty(value, 'wishlisted_by_uids'),
    );
  }
}

List<String> _arrayOrEmpty(Map<String, dynamic> data, String key) =>
    data.containsKey(key) ? stringList(data, key) : const <String>[];
