import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parsing.dart';
import 'flavor.dart';
import 'gelato_type.dart';

class CheckIn {
  /// Transitional constructor for legacy screens/tests. Remove in Client Task 6.
  CheckIn.legacy({
    required this.id,
    required this.userId,
    required Map<String, dynamic> userSummary,
    required this.placeId,
    required String placeName,
    required String photoUrl,
    required bool isLivePhoto,
    this.reviewText,
    required this.rating,
    this.gelatoType,
    required List<Flavor> flavors,
    required List<String> likedByUids,
    required List<String> wishlistedByUids,
    GeoPoint? location,
    required this.createdAt,
    List<String> taggedUserUids = const <String>[],
    Map<String, String> taggedUserNames = const <String, String>{},
    this.updatedAt,
  }) : flavors = List<Flavor>.unmodifiable(flavors),
       _consumedAt = null,
       userSnapshot = _legacyUserToCanonical(userSummary),
       placeSnapshot = Map<String, dynamic>.unmodifiable(<String, dynamic>{
         'name': placeName,
         'address': '',
       }),
       photoStoragePath = photoUrl,
       taggedUserIds = List<String>.unmodifiable(taggedUserUids),
       schemaVersion = 1,
       _legacyUserSummary = Map<String, dynamic>.unmodifiable(userSummary),
       _legacyPlaceName = placeName,
       _legacyPhotoUrl = photoUrl,
       _legacyIsLivePhoto = isLivePhoto,
       _legacyLikedByUids = List<String>.unmodifiable(likedByUids),
       _legacyWishlistedByUids = List<String>.unmodifiable(wishlistedByUids),
       _legacyLocation = location,
       _legacyTaggedUserNames = Map<String, String>.unmodifiable(
         taggedUserNames,
       ) {
    _requireCheckInId(id, 'document id');
  }

  const CheckIn._({
    required this.id,
    required this.userId,
    required this.userSnapshot,
    required this.placeId,
    required this.placeSnapshot,
    required this.photoStoragePath,
    required this.rating,
    required this.gelatoType,
    required this.flavors,
    required this.reviewText,
    required this.taggedUserIds,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    this._consumedAt,
    this._legacyUserSummary,
    this._legacyPlaceName,
    this._legacyPhotoUrl,
    this._legacyIsLivePhoto = false,
    this._legacyLikedByUids = const <String>[],
    this._legacyWishlistedByUids = const <String>[],
    this._legacyLocation,
    this._legacyTaggedUserNames = const <String, String>{},
  });

  final String id;
  final String userId;
  final Map<String, dynamic> userSnapshot;
  final String placeId;
  final Map<String, dynamic> placeSnapshot;
  final String photoStoragePath;
  final int rating;
  final GelatoType? gelatoType;
  final List<Flavor> flavors;
  final String? reviewText;
  final List<String> taggedUserIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int schemaVersion;

  /// Null for documents written before backdating shipped, and for legacy v1
  /// rows. [consumedAt] falls back to [createdAt] so callers never branch.
  final DateTime? _consumedAt;

  /// When the gelato was eaten. [createdAt] stays the write time and the feed
  /// cursor; this is the date the UI shows.
  DateTime get consumedAt => _consumedAt ?? createdAt;

  final Map<String, dynamic>? _legacyUserSummary;
  final String? _legacyPlaceName;
  final String? _legacyPhotoUrl;
  final bool _legacyIsLivePhoto;
  final List<String> _legacyLikedByUids;
  final List<String> _legacyWishlistedByUids;
  final GeoPoint? _legacyLocation;
  final Map<String, String> _legacyTaggedUserNames;

  // Transitional read-only accessors. Remove in Client Tasks 5-7.
  Map<String, dynamic> get userSummary =>
      _legacyUserSummary ??
      <String, dynamic>{
        'username': userSnapshot['display_name'],
        'avatar_url': userSnapshot['avatar_path'],
      };
  String get placeName => _legacyPlaceName ?? placeSnapshot['name'] as String;
  String get photoUrl => _legacyPhotoUrl ?? photoStoragePath;
  bool get isLivePhoto => _legacyIsLivePhoto;
  List<String> get likedByUids => _legacyLikedByUids;
  List<String> get wishlistedByUids => _legacyWishlistedByUids;
  GeoPoint? get location => _legacyLocation;
  List<String> get taggedUserUids => taggedUserIds;
  Map<String, String> get taggedUserNames => _legacyTaggedUserNames;

  factory CheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = _documentData(doc);
    _requireExactKeys(
      data,
      _canonicalKeys,
      'check-in',
      optional: _canonicalOptionalKeys,
    );
    if (requireInt(data, 'schema_version') != 2) {
      throw const FormatException('schema_version: expected 2');
    }
    final userId = requireString(data, 'user_id');
    final placeId = requireString(data, 'place_id');
    _requireCheckInId(doc.id, 'document id');
    _requireId(userId, 'user_id');
    _requireId(placeId, 'place_id');
    final rating = _rating(data);
    final reviewText = requireString(data, 'review_text');
    if (reviewText.length > 500) {
      throw const FormatException('review_text: exceeds 500 characters');
    }
    final taggedIds = stringList(data, 'tagged_user_ids');
    _validateTaggedIds(taggedIds, userId);
    final photoPath = requireString(data, 'photo_storage_path');
    _validatePhotoPath(photoPath, userId, doc.id);
    final typeSnapshot = _displaySnapshot(data, 'gelato_type', const <String>{
      'id',
      'name',
    });
    final flavorSnapshots = _flavorSnapshots(data, allowEmpty: false);
    return CheckIn._(
      id: doc.id,
      userId: userId,
      userSnapshot: _userSnapshot(data, 'user_snapshot'),
      placeId: placeId,
      placeSnapshot: _displaySnapshot(data, 'place_snapshot', const <String>{
        'name',
        'address',
      }),
      photoStoragePath: photoPath,
      rating: rating,
      gelatoType: GelatoType(
        id: requireString(typeSnapshot, 'id'),
        name: requireString(typeSnapshot, 'name'),
        sortOrder: 0,
      ),
      flavors: _flavorsFromSnapshots(flavorSnapshots),
      reviewText: reviewText,
      taggedUserIds: taggedIds,
      createdAt: requireTimestamp(data, 'created_at'),
      updatedAt: requireTimestamp(data, 'updated_at'),
      schemaVersion: 2,
      consumedAt: optionalTimestamp(data, 'consumed_at'),
    );
  }

  /// Explicit adapter for the pre-v2 client-written check-in schema.
  factory CheckIn.fromLegacyFirestore(DocumentSnapshot doc) {
    final data = _documentData(doc);
    if (data.keys.any(_canonicalOnlyKeys.contains)) {
      throw const FormatException('legacy check-in: canonical v2 fields found');
    }
    _requireCheckInId(doc.id, 'document id');
    final userId = requireString(data, 'user_id');
    final placeId = requireString(data, 'place_id');
    _requireId(userId, 'user_id');
    _requireId(placeId, 'place_id');
    final userSummary = _legacyUserSnapshot(data);
    final type = _optionalLegacyGelatoType(data);
    final taggedIds = stringList(data, 'tagged_user_uids');
    final names = _stringValuesMap(data, 'tagged_user_names');
    final location = data['location'];
    if (location != null && location is! GeoPoint) {
      throw const FormatException('location: expected GeoPoint or null');
    }
    return CheckIn._(
      id: doc.id,
      userId: userId,
      userSnapshot: _legacyUserToCanonical(userSummary),
      placeId: placeId,
      placeSnapshot: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        'name': requireString(data, 'place_name'),
        'address': '',
      }),
      photoStoragePath: requireString(data, 'photo_url'),
      rating: _rating(data),
      gelatoType: type,
      flavors: _legacyFlavors(data),
      reviewText: optionalString(data, 'review_text'),
      taggedUserIds: taggedIds,
      createdAt: requireTimestamp(data, 'created_at'),
      updatedAt: null,
      schemaVersion: 1,
      legacyUserSummary: userSummary,
      legacyPlaceName: requireString(data, 'place_name'),
      legacyPhotoUrl: requireString(data, 'photo_url'),
      legacyIsLivePhoto: _requireBool(data, 'is_live_photo'),
      legacyLikedByUids: stringList(data, 'liked_by_uids'),
      legacyWishlistedByUids: stringList(data, 'wishlisted_by_uids'),
      legacyLocation: location as GeoPoint?,
      legacyTaggedUserNames: names,
    );
  }
}

const Set<String> _canonicalKeys = <String>{
  'user_id',
  'user_snapshot',
  'place_id',
  'place_snapshot',
  'gelato_type',
  'flavors',
  'rating',
  'review_text',
  'tagged_user_ids',
  'photo_storage_path',
  'created_at',
  'updated_at',
  'schema_version',
};

/// Written since backdating shipped. Documents from before it have no
/// `consumed_at` and must keep parsing, so it can never join [_canonicalKeys].
const Set<String> _canonicalOptionalKeys = <String>{'consumed_at'};

const Set<String> _canonicalOnlyKeys = <String>{
  'user_snapshot',
  'place_snapshot',
  'tagged_user_ids',
  'photo_storage_path',
  'updated_at',
  'schema_version',
  'consumed_at',
};

Map<String, dynamic> _documentData(DocumentSnapshot doc) {
  final value = doc.data();
  if (value is! Map<String, dynamic>) {
    throw const FormatException('document: expected Map<String, dynamic>');
  }
  return value;
}

int _rating(Map<String, dynamic> data) {
  final value = requireInt(data, 'rating');
  if (value < 1 || value > 5) {
    throw const FormatException('rating: expected integer from 1 to 5');
  }
  return value;
}

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

List<Map<String, dynamic>> _flavorSnapshots(
  Map<String, dynamic> data, {
  required bool allowEmpty,
}) {
  final raw = data['flavors'];
  if (raw is! List || (!allowEmpty && raw.isEmpty) || raw.length > 4) {
    throw const FormatException('flavors: invalid snapshot list');
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
  return result;
}

List<Flavor> _flavorsFromSnapshots(List<Map<String, dynamic>> snapshots) =>
    List<Flavor>.unmodifiable(
      snapshots.map(
        (snapshot) => Flavor(
          id: requireString(snapshot, 'id'),
          name: requireString(snapshot, 'name'),
          colorHex: optionalString(snapshot, 'color_hex'),
        ),
      ),
    );

Map<String, dynamic> _legacyUserSnapshot(Map<String, dynamic> data) {
  final snapshot = stringMap(data, 'user_summary');
  _requireExactKeys(snapshot, const <String>{
    'username',
    'avatar_url',
  }, 'user_summary');
  requireString(snapshot, 'username');
  optionalString(snapshot, 'avatar_url');
  return snapshot;
}

Map<String, dynamic> _legacyUserToCanonical(Map<String, dynamic> summary) =>
    Map<String, dynamic>.unmodifiable(<String, dynamic>{
      'display_name': summary['username'] is String ? summary['username'] : '',
      'username': summary['username'] is String ? summary['username'] : '',
      'avatar_path': summary['avatar_url'] is String
          ? summary['avatar_url']
          : null,
    });

GelatoType? _optionalLegacyGelatoType(Map<String, dynamic> data) {
  final raw = data['gelato_type'];
  if (raw == null) return null;
  final snapshot = stringMap(<String, dynamic>{'value': raw}, 'value');
  _requireExactKeys(snapshot, const <String>{'id', 'name'}, 'gelato_type');
  return GelatoType(
    id: requireString(snapshot, 'id'),
    name: requireString(snapshot, 'name'),
    sortOrder: 0,
  );
}

List<Flavor> _legacyFlavors(Map<String, dynamic> data) {
  final raw = data['flavors'];
  if (raw is! List) throw const FormatException('flavors: expected list');
  final result = <Flavor>[];
  for (var index = 0; index < raw.length; index++) {
    final snapshot = stringMap(<String, dynamic>{'value': raw[index]}, 'value');
    final allowed = const <String>{'id', 'name', 'color_hex'};
    if (!allowed.containsAll(snapshot.keys) ||
        !snapshot.keys.toSet().containsAll(const <String>{'id', 'name'})) {
      throw FormatException('flavors[$index]: invalid fields');
    }
    result.add(
      Flavor(
        id: requireString(snapshot, 'id'),
        name: requireString(snapshot, 'name'),
        colorHex: optionalString(snapshot, 'color_hex'),
      ),
    );
  }
  return List<Flavor>.unmodifiable(result);
}

Map<String, String> _stringValuesMap(Map<String, dynamic> data, String key) {
  final raw = stringMap(data, key);
  final result = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! String) {
      throw FormatException('$key.${entry.key}: expected String');
    }
    result[entry.key] = value;
  }
  return Map<String, String>.unmodifiable(result);
}

bool _requireBool(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key) || data[key] is! bool) {
    throw FormatException('$key: expected bool');
  }
  return data[key] as bool;
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
  final prefix = 'check_ins/$authorUid/$checkInId/';
  final filename = path.startsWith(prefix) ? path.substring(prefix.length) : '';
  if (filename.isEmpty || filename.contains('/')) {
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
