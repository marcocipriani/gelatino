import 'firestore_parsing.dart';

class UserSettings {
  const UserSettings({
    required this.themeMode,
    required this.defaultCollectionView,
    required this.reducedMotion,
    required this.notificationsEnabled,
    required this.profileVisibility,
    required this.searchable,
  });

  final String themeMode;
  final String defaultCollectionView;
  final bool reducedMotion;
  final bool notificationsEnabled;
  final String profileVisibility;
  final bool searchable;

  factory UserSettings.fromMap(Map<String, dynamic> data) {
    final themeMode = _stringOrDefault(data, 'theme_mode', 'system');
    final collectionView = _stringOrDefault(
      data,
      'default_collection_view',
      'list',
    );
    final visibility = _stringOrDefault(data, 'profile_visibility', 'private');
    _requireOneOf(themeMode, const {'system', 'light', 'dark'}, 'theme_mode');
    _requireOneOf(collectionView, const {
      'list',
      'map',
    }, 'default_collection_view');
    _requireOneOf(visibility, const {
      'public',
      'friends',
      'private',
    }, 'profile_visibility');
    return UserSettings(
      themeMode: themeMode,
      defaultCollectionView: collectionView,
      reducedMotion: optionalBool(data, 'reduced_motion'),
      notificationsEnabled: optionalBool(
        data,
        'notifications_enabled',
        fallback: true,
      ),
      profileVisibility: visibility,
      searchable: optionalBool(data, 'searchable'),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'theme_mode': themeMode,
    'default_collection_view': defaultCollectionView,
    'reduced_motion': reducedMotion,
    'notifications_enabled': notificationsEnabled,
    'profile_visibility': profileVisibility,
    'searchable': searchable,
  };

  UserSettings copyWith({
    String? themeMode,
    String? defaultCollectionView,
    bool? reducedMotion,
    bool? notificationsEnabled,
    String? profileVisibility,
    bool? searchable,
  }) => UserSettings(
    themeMode: themeMode ?? this.themeMode,
    defaultCollectionView: defaultCollectionView ?? this.defaultCollectionView,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    profileVisibility: profileVisibility ?? this.profileVisibility,
    searchable: searchable ?? this.searchable,
  );
}

String _stringOrDefault(
  Map<String, dynamic> data,
  String key,
  String fallback,
) => data.containsKey(key) ? requireString(data, key) : fallback;

void _requireOneOf(String value, Set<String> allowed, String key) {
  if (!allowed.contains(value)) {
    throw FormatException('$key: invalid value $value');
  }
}
