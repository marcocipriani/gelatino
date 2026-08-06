import 'firestore_parsing.dart';
import 'gelato_level.dart';
import 'profile_view_data.dart';

sealed class FieldPatch<T> {
  const FieldPatch();
}

final class Keep<T> extends FieldPatch<T> {
  const Keep();
}

final class SetValue<T> extends FieldPatch<T> {
  const SetValue(this.value);

  final T value;
}

final class Clear<T> extends FieldPatch<T> {
  const Clear();
}

class UserProfile implements ProfileViewData {
  UserProfile({
    required this.uid,
    required this.displayName,
    this.username = '',
    this.bio = '',
    this.city = '',
    this.avatarPath,
    String? photoUrl,
    this.favoritePlaceId,
    String? favoriteGelateria,
    this.favoriteFlavorId,
    String? favoriteFlavor,
    List<String> favoriteFlavorIds = const <String>[],
    List<String>? favoriteFlavors,
    this.points = 0,
    List<String> friendUids = const <String>[],
    this.defaultView = 'list',
    this.isPrivate = false,
    List<String> dismissedBadgeNotifications = const <String>[],
    Map<String, int> affinity = const <String, int>{},
    Map<String, int> monthlyPoints = const <String, int>{},
    this.lastActive,
    bool canonicalAvatarPathPresent = false,
    bool canonicalFavoritePlaceIdPresent = false,
    bool canonicalFavoriteFlavorIdPresent = false,
    bool canonicalFavoriteFlavorIdsPresent = false,
  }) : favoriteFlavorIds = List<String>.unmodifiable(favoriteFlavorIds),
       _hasCanonicalAvatarPath =
           canonicalAvatarPathPresent || avatarPath != null,
       _hasCanonicalFavoritePlaceId =
           canonicalFavoritePlaceIdPresent || favoritePlaceId != null,
       _hasCanonicalFavoriteFlavorId =
           canonicalFavoriteFlavorIdPresent || favoriteFlavorId != null,
       _hasCanonicalFavoriteFlavorIds =
           canonicalFavoriteFlavorIdsPresent || favoriteFlavorIds.isNotEmpty,
       _legacyPhotoUrl = photoUrl,
       _legacyFavoriteGelateria = favoriteGelateria,
       _legacyFavoriteFlavor = favoriteFlavor,
       _legacyFavoriteFlavors = favoriteFlavors == null
           ? null
           : List<String>.unmodifiable(favoriteFlavors),
       friendUids = List<String>.unmodifiable(friendUids),
       dismissedBadgeNotifications = List<String>.unmodifiable(
         dismissedBadgeNotifications,
       ),
       affinity = Map<String, int>.unmodifiable(affinity),
       monthlyPoints = Map<String, int>.unmodifiable(monthlyPoints);

  @override
  final String uid;
  @override
  final String displayName;
  final String username;
  final String bio;
  final String city;
  final String? avatarPath;
  final String? favoritePlaceId;
  final String? favoriteFlavorId;
  @override
  final List<String> favoriteFlavorIds;
  @override
  final int points;
  final Map<String, int> monthlyPoints;

  GelatoLevel get level => GelatoLevel.forPoints(points);

  // Transitional read-only surface. Remove across Client Tasks 3-5.
  @override
  String? get photoUrl => _hasCanonicalAvatarPath || avatarPath != null
      ? avatarPath
      : _legacyPhotoUrl;
  @override
  String? get favoriteGelateria =>
      _hasCanonicalFavoritePlaceId || favoritePlaceId != null
      ? favoritePlaceId
      : _legacyFavoriteGelateria;
  @override
  String? get favoriteFlavor =>
      _hasCanonicalFavoriteFlavorId || favoriteFlavorId != null
      ? favoriteFlavorId
      : _legacyFavoriteFlavor;
  @override
  List<String> get favoriteFlavors =>
      _hasCanonicalFavoriteFlavorIds || favoriteFlavorIds.isNotEmpty
      ? favoriteFlavorIds
      : _legacyFavoriteFlavors ?? favoriteFlavorIds;
  final bool _hasCanonicalAvatarPath;
  final bool _hasCanonicalFavoritePlaceId;
  final bool _hasCanonicalFavoriteFlavorId;
  final bool _hasCanonicalFavoriteFlavorIds;
  final String? _legacyPhotoUrl;
  final String? _legacyFavoriteGelateria;
  final String? _legacyFavoriteFlavor;
  final List<String>? _legacyFavoriteFlavors;
  final List<String> friendUids;
  final String defaultView;
  final bool isPrivate;
  final List<String> dismissedBadgeNotifications;
  final Map<String, int> affinity;
  final DateTime? lastActive;

  factory UserProfile.fromMap(Map<String, dynamic> data, String id) {
    requirePathSegment(id, 'document id');
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
    return UserProfile(
      uid: id,
      displayName: requireString(data, 'display_name'),
      username: requireString(data, 'username'),
      bio: requireString(data, 'bio'),
      city: requireString(data, 'city'),
      avatarPath: optionalStoragePath(data, 'avatar_path'),
      favoritePlaceId: favoritePlaceId,
      favoriteFlavorId: favoriteFlavorId,
      favoriteFlavorIds: favoriteFlavorIds,
      points: points,
      monthlyPoints: monthlyPoints,
      canonicalAvatarPathPresent: data.containsKey('avatar_path'),
      canonicalFavoritePlaceIdPresent: data.containsKey('favorite_place_id'),
      canonicalFavoriteFlavorIdPresent: data.containsKey('favorite_flavor_id'),
      canonicalFavoriteFlavorIdsPresent: data.containsKey(
        'favorite_flavor_ids',
      ),
    );
  }

  /// Explicit adapter for the pre-migration private profile shape.
  factory UserProfile.fromLegacyMap(Map<String, dynamic> data, String id) {
    requirePathSegment(id, 'document id');
    final points = requireInt(data, 'points');
    if (points < 0) throw const FormatException('points: must be non-negative');
    final affinity = _affinityOrEmpty(data);
    final monthlyPoints = monthlyPointsFrom(data);
    return UserProfile(
      uid: id,
      displayName: requireString(data, 'display_name'),
      photoUrl: optionalString(data, 'photo_url'),
      favoriteGelateria: optionalString(data, 'favorite_gelateria'),
      favoriteFlavor: optionalString(data, 'favorite_flavor'),
      favoriteFlavors: _stringListOrEmpty(data, 'favorite_flavors'),
      points: points,
      friendUids: _stringListOrEmpty(data, 'friend_uids'),
      defaultView: _stringOrDefault(data, 'default_view', 'list'),
      isPrivate: optionalBool(data, 'is_private'),
      dismissedBadgeNotifications: _optionalStringList(
        data,
        'dismissed_badge_notifications',
      ),
      affinity: affinity,
      monthlyPoints: monthlyPoints,
      lastActive: optionalTimestamp(data, 'last_active'),
    );
  }

  /// Explicit adapter for documents containing canonical and legacy fields.
  factory UserProfile.fromMigrationMap(Map<String, dynamic> data, String id) {
    requirePathSegment(id, 'document id');
    final points = requireInt(data, 'points');
    if (points < 0) throw const FormatException('points: must be non-negative');
    final monthlyPoints = monthlyPointsFrom(data);

    final favoritePlaceId = optionalString(data, 'favorite_place_id');
    final favoriteFlavorId = optionalString(data, 'favorite_flavor_id');
    final favoriteFlavorIds = _stringListOrEmpty(data, 'favorite_flavor_ids');
    if (favoritePlaceId != null) {
      requirePathSegment(favoritePlaceId, 'favorite_place_id');
    }
    if (favoriteFlavorId != null) {
      requirePathSegment(favoriteFlavorId, 'favorite_flavor_id');
    }
    _requireUniqueIds(favoriteFlavorIds, 'favorite_flavor_ids');

    final visibility = data.containsKey('profile_visibility')
        ? requireString(data, 'profile_visibility')
        : null;
    if (visibility != null &&
        !const {'public', 'friends', 'private'}.contains(visibility)) {
      throw FormatException('profile_visibility: invalid value $visibility');
    }

    return UserProfile(
      uid: id,
      displayName: requireString(data, 'display_name'),
      username: _stringOrDefault(data, 'username', ''),
      bio: _stringOrDefault(data, 'bio', ''),
      city: _stringOrDefault(data, 'city', ''),
      avatarPath: optionalStoragePath(data, 'avatar_path'),
      favoritePlaceId: favoritePlaceId,
      favoriteFlavorId: favoriteFlavorId,
      favoriteFlavorIds: favoriteFlavorIds,
      photoUrl: optionalString(data, 'photo_url'),
      favoriteGelateria: optionalString(data, 'favorite_gelateria'),
      favoriteFlavor: optionalString(data, 'favorite_flavor'),
      favoriteFlavors: _stringListOrEmpty(data, 'favorite_flavors'),
      points: points,
      friendUids: _stringListOrEmpty(data, 'friend_uids'),
      defaultView: _stringOrDefault(data, 'default_view', 'list'),
      isPrivate: visibility == null
          ? optionalBool(data, 'is_private')
          : visibility == 'private',
      dismissedBadgeNotifications: _optionalStringList(
        data,
        'dismissed_badge_notifications',
      ),
      affinity: _affinityOrEmpty(data),
      monthlyPoints: monthlyPoints,
      lastActive: optionalTimestamp(data, 'last_active'),
      canonicalAvatarPathPresent: data.containsKey('avatar_path'),
      canonicalFavoritePlaceIdPresent: data.containsKey('favorite_place_id'),
      canonicalFavoriteFlavorIdPresent: data.containsKey('favorite_flavor_id'),
      canonicalFavoriteFlavorIdsPresent: data.containsKey(
        'favorite_flavor_ids',
      ),
    );
  }

  /// Explicit adapter for sparse private documents accepted during migration.
  factory UserProfile.fromBackendCompatibleMap(
    Map<String, dynamic> data,
    String id,
  ) {
    requirePathSegment(id, 'document id');
    final points = requireInt(data, 'points');
    if (points < 0) throw const FormatException('points: must be non-negative');
    final monthlyPoints = monthlyPointsFrom(data);
    final favoriteFlavorIds = _stringListOrEmpty(data, 'favorite_flavor_ids');
    _requireUniqueIds(favoriteFlavorIds, 'favorite_flavor_ids');
    final favoritePlaceId = optionalString(data, 'favorite_place_id');
    final favoriteFlavorId = optionalString(data, 'favorite_flavor_id');
    if (favoritePlaceId != null) {
      requirePathSegment(favoritePlaceId, 'favorite_place_id');
    }
    if (favoriteFlavorId != null) {
      requirePathSegment(favoriteFlavorId, 'favorite_flavor_id');
    }
    final visibility = _stringOrDefault(data, 'profile_visibility', 'private');
    if (!const {'public', 'friends', 'private'}.contains(visibility)) {
      throw FormatException('profile_visibility: invalid value $visibility');
    }
    return UserProfile(
      uid: id,
      displayName: _stringOrDefault(data, 'display_name', ''),
      username: _stringOrDefault(data, 'username', ''),
      bio: _stringOrDefault(data, 'bio', ''),
      city: _stringOrDefault(data, 'city', ''),
      avatarPath: optionalStoragePath(data, 'avatar_path'),
      favoritePlaceId: favoritePlaceId,
      favoriteFlavorId: favoriteFlavorId,
      favoriteFlavorIds: favoriteFlavorIds,
      points: points,
      isPrivate: visibility == 'private',
      affinity: _affinityOrEmpty(data),
      monthlyPoints: monthlyPoints,
      canonicalAvatarPathPresent: data.containsKey('avatar_path'),
      canonicalFavoritePlaceIdPresent: data.containsKey('favorite_place_id'),
      canonicalFavoriteFlavorIdPresent: data.containsKey('favorite_flavor_id'),
      canonicalFavoriteFlavorIdsPresent: data.containsKey(
        'favorite_flavor_ids',
      ),
    );
  }

  /// Editable owner fields only; server points/settings/social data are omitted.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'display_name': displayName,
    'username': username,
    'bio': bio,
    'city': city,
    if (_hasCanonicalAvatarPath) 'avatar_path': avatarPath,
    if (_hasCanonicalFavoritePlaceId) 'favorite_place_id': favoritePlaceId,
    if (_hasCanonicalFavoriteFlavorId) 'favorite_flavor_id': favoriteFlavorId,
    if (_hasCanonicalFavoriteFlavorIds)
      'favorite_flavor_ids': favoriteFlavorIds,
  };

  Map<String, dynamic> toInitialCreateMap() {
    if (points != 0) {
      throw StateError('New profiles must start with zero server points');
    }
    return <String, dynamic>{
      'display_name': displayName,
      'username': username,
      'bio': bio,
      'city': city,
      'avatar_path': avatarPath,
      'favorite_place_id': favoritePlaceId,
      'favorite_flavor_id': favoriteFlavorId,
      'favorite_flavor_ids': favoriteFlavorIds,
      'points': 0,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? city,
    FieldPatch<String> avatarPath = const Keep<String>(),
    FieldPatch<String> favoritePlaceId = const Keep<String>(),
    FieldPatch<String> favoriteFlavorId = const Keep<String>(),
    List<String>? favoriteFlavorIds,
    List<String>? favoriteFlavors,
    String? defaultView,
    bool? isPrivate,
    List<String>? dismissedBadgeNotifications,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      avatarPath: _applyPatch(avatarPath, this.avatarPath),
      favoritePlaceId: _applyPatch(favoritePlaceId, this.favoritePlaceId),
      favoriteFlavorId: _applyPatch(favoriteFlavorId, this.favoriteFlavorId),
      favoriteFlavorIds:
          favoriteFlavors ?? favoriteFlavorIds ?? this.favoriteFlavorIds,
      photoUrl: _legacyPhotoUrl,
      favoriteGelateria: _legacyFavoriteGelateria,
      favoriteFlavor: _legacyFavoriteFlavor,
      favoriteFlavors: _legacyFavoriteFlavors,
      points: points,
      friendUids: friendUids,
      defaultView: defaultView ?? this.defaultView,
      isPrivate: isPrivate ?? this.isPrivate,
      dismissedBadgeNotifications:
          dismissedBadgeNotifications ?? this.dismissedBadgeNotifications,
      affinity: affinity,
      monthlyPoints: monthlyPoints,
      lastActive: lastActive,
      canonicalAvatarPathPresent: switch (avatarPath) {
        Keep<String>() => _hasCanonicalAvatarPath,
        _ => true,
      },
      canonicalFavoritePlaceIdPresent: switch (favoritePlaceId) {
        Keep<String>() => _hasCanonicalFavoritePlaceId,
        _ => true,
      },
      canonicalFavoriteFlavorIdPresent: switch (favoriteFlavorId) {
        Keep<String>() => _hasCanonicalFavoriteFlavorId,
        _ => true,
      },
      canonicalFavoriteFlavorIdsPresent:
          favoriteFlavors != null || favoriteFlavorIds != null
          ? true
          : _hasCanonicalFavoriteFlavorIds,
    );
  }
}

T? _applyPatch<T>(FieldPatch<T> patch, T? current) => switch (patch) {
  Keep<T>() => current,
  SetValue<T>(:final value) => value,
  Clear<T>() => null,
};

List<String> _optionalStringList(Map<String, dynamic> data, String key) {
  return data.containsKey(key) ? stringList(data, key) : const <String>[];
}

String _stringOrDefault(
  Map<String, dynamic> data,
  String key,
  String fallback,
) => data.containsKey(key) ? requireString(data, key) : fallback;

List<String> _stringListOrEmpty(Map<String, dynamic> data, String key) =>
    data.containsKey(key) ? stringList(data, key) : const <String>[];

Map<String, int> _affinityOrEmpty(Map<String, dynamic> data) {
  if (!data.containsKey('affinity')) return const <String, int>{};
  final raw = stringMap(data, 'affinity');
  final result = <String, int>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! int || value < 0) {
      throw FormatException('affinity.${entry.key}: expected non-negative int');
    }
    result[entry.key] = value;
  }
  return Map<String, int>.unmodifiable(result);
}

void _requireUniqueIds(List<String> values, String label) {
  if (values.toSet().length != values.length) {
    throw FormatException('$label: IDs must be unique');
  }
  for (final value in values) {
    requirePathSegment(value, label);
  }
}
