import 'firestore_parsing.dart';

class PlaceState {
  const PlaceState({
    required this.placeId,
    required this.saved,
    required this.savedAt,
    required this.favorite,
    required this.favoriteAt,
    required this.liked,
    required this.likedAt,
    required this.note,
    required this.updatedAt,
  });

  final String placeId;
  final bool saved;
  final DateTime? savedAt;
  final bool favorite;
  final DateTime? favoriteAt;
  final bool liked;
  final DateTime? likedAt;
  final String? note;
  final DateTime? updatedAt;

  factory PlaceState.empty(String placeId) {
    _requireId(placeId);
    return PlaceState(
      placeId: placeId,
      saved: false,
      savedAt: null,
      favorite: false,
      favoriteAt: null,
      liked: false,
      likedAt: null,
      note: null,
      updatedAt: null,
    );
  }

  PlaceState copyWith({bool? saved, bool? favorite, bool? liked}) {
    return PlaceState(
      placeId: placeId,
      saved: saved ?? this.saved,
      savedAt: saved == false ? null : savedAt,
      favorite: favorite ?? this.favorite,
      favoriteAt: favorite == false ? null : favoriteAt,
      liked: liked ?? this.liked,
      likedAt: liked == false ? null : likedAt,
      note: note,
      updatedAt: updatedAt,
    );
  }

  factory PlaceState.fromMap(Map<String, dynamic> data, String placeId) {
    _requireId(placeId);
    final note = optionalString(data, 'note');
    if (note != null && note.length > 500) {
      throw const FormatException('note: exceeds 500 characters');
    }
    return PlaceState(
      placeId: placeId,
      saved: optionalBool(data, 'saved'),
      savedAt: optionalTimestamp(data, 'saved_at'),
      favorite: optionalBool(data, 'favorite'),
      favoriteAt: optionalTimestamp(data, 'favorite_at'),
      liked: optionalBool(data, 'liked'),
      likedAt: optionalTimestamp(data, 'liked_at'),
      note: note,
      updatedAt: optionalTimestamp(data, 'updated_at'),
    );
  }
}

final RegExp _validId = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');

void _requireId(String value) {
  if (!_validId.hasMatch(value)) {
    throw const FormatException('placeId: invalid ID');
  }
}
