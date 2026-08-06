import 'firestore_parsing.dart';

class FeedItem {
  const FeedItem._({
    required this.authorUid,
    required this.checkInId,
    required this.userSnapshot,
    required this.placeId,
    required this.placeSnapshot,
    required this.gelatoType,
    required this.flavors,
    required this.rating,
    required this.reviewText,
    required this.taggedUserIds,
    required this.createdAt,
    required this.photoStoragePath,
    this._consumedAt,
  });

  final String authorUid;
  final String checkInId;
  final Map<String, dynamic> userSnapshot;
  final String placeId;
  final Map<String, dynamic> placeSnapshot;
  final Map<String, dynamic> gelatoType;
  final List<Map<String, dynamic>> flavors;
  final int rating;
  final String reviewText;
  final List<String> taggedUserIds;
  final DateTime createdAt;
  final String photoStoragePath;

  /// Null for feed items projected before backdating shipped. [consumedAt]
  /// falls back to [createdAt] so callers never branch.
  final DateTime? _consumedAt;

  /// When the gelato was eaten. [createdAt] stays the projection time and the
  /// feed cursor; this is the date the card shows.
  DateTime get consumedAt => _consumedAt ?? createdAt;

  /// True when the check-in was backdated far enough that showing only
  /// [consumedAt] would make a fresh post look stale.
  bool get isBackdated => consumedAt.difference(createdAt).abs().inDays >= 1;

  factory FeedItem.fromMap(Map<String, dynamic> data, String documentId) {
    _requireExactKeys(
      data,
      _feedItemKeys,
      'feed item',
      optional: _feedItemOptionalKeys,
    );
    _requireCheckInId(documentId, 'document id');
    final checkInId = requireString(data, 'check_in_id');
    _requireCheckInId(checkInId, 'check_in_id');
    if (checkInId != documentId) {
      throw FormatException('check_in_id: expected $documentId');
    }
    final authorUid = requireString(data, 'author_uid');
    final placeId = requireString(data, 'place_id');
    _requireId(authorUid, 'author_uid');
    _requireId(placeId, 'place_id');
    final rating = requireInt(data, 'rating');
    if (rating < 1 || rating > 5) {
      throw const FormatException('rating: expected integer from 1 to 5');
    }
    final reviewText = requireString(data, 'review_text');
    if (reviewText.length > 500) {
      throw const FormatException('review_text: exceeds 500 characters');
    }
    final taggedUserIds = stringList(data, 'tagged_user_ids');
    _validateTaggedIds(taggedUserIds, authorUid);
    final photoStoragePath = requireString(data, 'photo_storage_path');
    _validatePhotoPath(photoStoragePath, authorUid, checkInId);

    return FeedItem._(
      authorUid: authorUid,
      checkInId: checkInId,
      userSnapshot: _userSnapshot(data, 'user_snapshot'),
      placeId: placeId,
      placeSnapshot: _displaySnapshot(data, 'place_snapshot', const <String>{
        'name',
        'address',
      }),
      gelatoType: _displaySnapshot(data, 'gelato_type', const <String>{
        'id',
        'name',
      }),
      flavors: _flavorSnapshots(data),
      rating: rating,
      reviewText: reviewText,
      taggedUserIds: taggedUserIds,
      createdAt: requireTimestamp(data, 'created_at'),
      photoStoragePath: photoStoragePath,
      consumedAt: optionalTimestamp(data, 'consumed_at'),
    );
  }
}

const Set<String> _feedItemKeys = <String>{
  'author_uid',
  'check_in_id',
  'user_snapshot',
  'place_id',
  'place_snapshot',
  'gelato_type',
  'flavors',
  'rating',
  'review_text',
  'tagged_user_ids',
  'created_at',
  'photo_storage_path',
};

/// Projected since backdating shipped. Feed items written before it have no
/// `consumed_at`, so it can never join [_feedItemKeys].
const Set<String> _feedItemOptionalKeys = <String>{'consumed_at'};

Map<String, dynamic> _userSnapshot(Map<String, dynamic> data, String key) {
  final snapshot = stringMap(data, key);
  _requireExactKeys(snapshot, const <String>{
    'display_name',
    'username',
    'avatar_path',
  }, key);
  requireString(snapshot, 'display_name');
  requireString(snapshot, 'username');
  optionalString(snapshot, 'avatar_path');
  return snapshot;
}

Map<String, dynamic> _displaySnapshot(
  Map<String, dynamic> data,
  String key,
  Set<String> keys,
) {
  final snapshot = stringMap(data, key);
  _requireExactKeys(snapshot, keys, key);
  for (final field in keys) {
    final value = requireString(snapshot, field);
    if (field == 'id') _requireId(value, '$key.$field');
  }
  return snapshot;
}

final RegExp _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

List<Map<String, dynamic>> _flavorSnapshots(Map<String, dynamic> data) {
  final raw = data['flavors'];
  if (raw is! List || raw.isEmpty || raw.length > 4) {
    throw const FormatException('flavors: expected 1 to 4 snapshots');
  }
  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < raw.length; index++) {
    final snapshot = stringMap(<String, dynamic>{'value': raw[index]}, 'value');
    final allowed = const <String>{'id', 'name', 'color_hex'};
    if (!allowed.containsAll(snapshot.keys) ||
        !snapshot.keys.toSet().containsAll(const <String>{'id', 'name'})) {
      throw FormatException('flavors[$index]: invalid fields');
    }
    _requireId(requireString(snapshot, 'id'), 'flavors[$index].id');
    requireString(snapshot, 'name');
    if (snapshot.containsKey('color_hex')) {
      final colorHex = optionalString(snapshot, 'color_hex');
      if (colorHex != null && !_hexColor.hasMatch(colorHex)) {
        throw FormatException('flavors[$index].color_hex: invalid color');
      }
    }
    result.add(snapshot);
  }
  return List<Map<String, dynamic>>.unmodifiable(result);
}

/// Every key in [expected] must be present and no key outside
/// [expected] + [optional] may appear. [optional] exists so a field added after
/// documents were already written does not invalidate the older ones.
void _requireExactKeys(
  Map<String, dynamic> data,
  Set<String> expected,
  String label, {
  Set<String> optional = const <String>{},
}) {
  final keys = data.keys.toSet();
  if (!keys.containsAll(expected) ||
      !expected.union(optional).containsAll(keys)) {
    throw FormatException('$label: invalid fields');
  }
}

void _validateTaggedIds(List<String> ids, String authorUid) {
  if (ids.length > 10 ||
      ids.toSet().length != ids.length ||
      ids.contains(authorUid)) {
    throw const FormatException('tagged_user_ids: invalid membership');
  }
  for (final id in ids) {
    _requireId(id, 'tagged_user_ids');
  }
}

void _validatePhotoPath(String path, String authorUid, String checkInId) {
  requireStoragePath(path, 'photo_storage_path');
  final segments = path.split('/');
  if (segments.length != 4 ||
      segments[0] != 'check_ins' ||
      segments[1] != authorUid ||
      segments[2] != checkInId ||
      segments[3].isEmpty) {
    throw const FormatException('photo_storage_path: invalid canonical path');
  }
}

final RegExp _validId = RegExp(r'^[^/\x00-\x1F\x7F]{1,128}$');
final RegExp _validCheckInId = RegExp(r'^[A-Za-z0-9_-]{20,64}$');

void _requireId(String value, String label) {
  if (!_validId.hasMatch(value)) throw FormatException('$label: invalid ID');
}

void _requireCheckInId(String value, String label) {
  if (!_validCheckInId.hasMatch(value)) {
    throw FormatException('$label: invalid check-in ID');
  }
}
