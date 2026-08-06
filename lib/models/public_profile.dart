import 'firestore_parsing.dart';
import 'gelato_level.dart';
import 'profile_view_data.dart';

class PublicProfile implements ProfileViewData {
  const PublicProfile._({
    required this.uid,
    required this.displayName,
    required this.displayNameLower,
    required this.username,
    required this.usernameLower,
    required this.avatarPath,
    required this.bio,
    required this.city,
    required this.favoritePlaceId,
    required this.favoriteFlavorId,
    required this.favoriteFlavorIds,
    required this.profileVisibility,
    required this.searchable,
    required this.points,
    required this.monthlyPoints,
    required this.updatedAt,
  });

  @override
  final String uid;
  @override
  final String displayName;
  final String displayNameLower;
  final String username;
  final String usernameLower;
  final String? avatarPath;
  final String bio;
  final String city;
  final String? favoritePlaceId;
  final String? favoriteFlavorId;
  @override
  final List<String> favoriteFlavorIds;
  final String profileVisibility;
  final bool searchable;
  @override
  final int points;
  final Map<String, int> monthlyPoints;
  final DateTime updatedAt;

  GelatoLevel get level => GelatoLevel.forPoints(points);

  @override
  String? get photoUrl => avatarPath;

  @override
  String? get favoriteGelateria => favoritePlaceId;

  @override
  String? get favoriteFlavor => favoriteFlavorId;

  @override
  List<String> get favoriteFlavors => favoriteFlavorIds;

  factory PublicProfile.fromMap(Map<String, dynamic> data, String documentId) {
    _requireExactKeys(data, _publicProfileKeys, 'public profile');
    requirePathSegment(documentId, 'document id');
    final uid = requireString(data, 'uid');
    requirePathSegment(uid, 'uid');
    if (uid != documentId) {
      throw FormatException('uid: expected $documentId, got $uid');
    }

    final visibility = requireString(data, 'profile_visibility');
    if (!const {'public', 'friends', 'private'}.contains(visibility)) {
      throw FormatException('profile_visibility: invalid value $visibility');
    }
    final points = requireInt(data, 'points');
    if (points < 0) throw const FormatException('points: must be non-negative');
    final monthlyPoints = monthlyPointsFrom(data);

    final favoriteFlavorIds = stringList(data, 'favorite_flavor_ids');
    _requireUniqueIds(favoriteFlavorIds, 'favorite_flavor_ids');
    final favoritePlaceId = optionalString(data, 'favorite_place_id');
    final favoriteFlavorId = optionalString(data, 'favorite_flavor_id');
    if (favoritePlaceId != null) {
      requirePathSegment(favoritePlaceId, 'favorite_place_id');
    }
    if (favoriteFlavorId != null) {
      requirePathSegment(favoriteFlavorId, 'favorite_flavor_id');
    }

    return PublicProfile._(
      uid: uid,
      displayName: requireString(data, 'display_name'),
      displayNameLower: requireString(data, 'display_name_lower'),
      username: requireString(data, 'username'),
      usernameLower: requireString(data, 'username_lower'),
      avatarPath: optionalStoragePath(data, 'avatar_path'),
      bio: requireString(data, 'bio'),
      city: requireString(data, 'city'),
      favoritePlaceId: favoritePlaceId,
      favoriteFlavorId: favoriteFlavorId,
      favoriteFlavorIds: favoriteFlavorIds,
      profileVisibility: visibility,
      searchable: _requireBool(data, 'searchable'),
      points: points,
      monthlyPoints: monthlyPoints,
      updatedAt: requireTimestamp(data, 'updated_at'),
    );
  }
}

const Set<String> _publicProfileKeys = <String>{
  'uid',
  'display_name',
  'display_name_lower',
  'username',
  'username_lower',
  'avatar_path',
  'bio',
  'city',
  'favorite_place_id',
  'favorite_flavor_id',
  'favorite_flavor_ids',
  'profile_visibility',
  'searchable',
  'points',
  'monthly_points',
  'updated_at',
};

const Set<String> _optionalProfileKeys = <String>{'monthly_points'};

void _requireExactKeys(
  Map<String, dynamic> data,
  Set<String> expected,
  String label,
) {
  final keys = data.keys.toSet();
  final required = expected.difference(_optionalProfileKeys);
  if (!expected.containsAll(keys) || !keys.containsAll(required)) {
    throw FormatException('$label: invalid fields');
  }
}

bool _requireBool(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key) || data[key] == null) {
    throw FormatException('$key: expected bool, got null');
  }
  return optionalBool(data, key);
}

void _requireUniqueIds(List<String> values, String label) {
  if (values.toSet().length != values.length) {
    throw FormatException('$label: IDs must be unique');
  }
  for (final value in values) {
    requirePathSegment(value, label);
  }
}
