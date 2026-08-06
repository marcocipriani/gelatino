import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/public_profile.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';

export '../models/user_profile.dart' show FieldPatch, Keep, SetValue, Clear;

final class ProfileDocument {
  const ProfileDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class PublicProfilePrefixQuery {
  const PublicProfilePrefixQuery({
    required this.orderByField,
    required this.startAt,
    required this.endAt,
    required this.limit,
  });

  final String collectionPath = 'public_profiles';
  final bool searchable = true;
  final String profileVisibility = 'public';
  final String orderByField;
  final String startAt;
  final String endAt;
  final int limit;
}

final class ProfileDelete {
  const ProfileDelete();
}

abstract interface class ProfileDataSource {
  Stream<ProfileDocument?> watchDocument(String path);

  Future<ProfileDocument?> readDocument(String path);

  Future<void> createDocumentIfAbsent(String path, Map<String, Object?> data);

  Future<void> updateDocument(String path, Map<String, Object?> data);

  Future<List<ProfileDocument>> queryPublicProfiles(
    PublicProfilePrefixQuery query,
  );
}

final class FirestoreProfileDataSource implements ProfileDataSource {
  FirestoreProfileDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<ProfileDocument?> watchDocument(String path) {
    return _firestore.doc(path).snapshots().map(_toProfileDocument);
  }

  @override
  Future<ProfileDocument?> readDocument(String path) async {
    return _toProfileDocument(await _firestore.doc(path).get());
  }

  @override
  Future<void> createDocumentIfAbsent(
    String path,
    Map<String, Object?> data,
  ) async {
    final reference = _firestore.doc(path);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.set(reference, Map<String, Object?>.from(data));
      }
    });
  }

  @override
  Future<void> updateDocument(String path, Map<String, Object?> data) async {
    final firebaseData = <String, Object?>{
      for (final entry in data.entries)
        entry.key: entry.value is ProfileDelete
            ? FieldValue.delete()
            : entry.value,
    };
    await _firestore.doc(path).update(firebaseData);
  }

  @override
  Future<List<ProfileDocument>> queryPublicProfiles(
    PublicProfilePrefixQuery query,
  ) async {
    final snapshot = await _firestore
        .collection(query.collectionPath)
        .where('searchable', isEqualTo: query.searchable)
        .where('profile_visibility', isEqualTo: query.profileVisibility)
        .orderBy(query.orderByField)
        .startAt(<Object?>[query.startAt])
        .endAt(<Object?>[query.endAt])
        .limit(query.limit)
        .get();
    return snapshot.docs
        .map(
          (document) => ProfileDocument(id: document.id, data: document.data()),
        )
        .toList(growable: false);
  }
}

ProfileDocument? _toProfileDocument(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
) {
  final data = snapshot.data();
  if (!snapshot.exists || data == null) return null;
  return ProfileDocument(id: snapshot.id, data: data);
}

abstract interface class ProfileRepository {
  Stream<UserProfile?> watchOwnProfile(String uid);

  Stream<UserSettings?> watchOwnSettings(String uid);

  Stream<PublicProfile?> watchPublicProfile(String uid);

  Future<PublicProfile?> readPublicProfile(String uid);

  Future<List<PublicProfile>> searchPublicProfiles(
    String query, {
    int limit = 20,
  });

  Future<void> ensureOwnProfile({
    required String uid,
    required String displayName,
  });

  Future<void> updateProfile(String uid, ProfilePatch patch);

  Future<void> updateThemeMode(String uid, String themeMode);

  Future<void> updateDefaultCollectionView(
    String uid,
    String defaultCollectionView,
  );

  Future<void> updatePrivacy(String uid, {required bool isPrivate});
}

final class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._source);

  final ProfileDataSource _source;

  @override
  Stream<UserProfile?> watchOwnProfile(String uid) {
    requirePathSegment(uid, 'uid');
    return _source
        .watchDocument('users/$uid')
        .map((document) => parseOwnProfileDocument(document));
  }

  @override
  Stream<UserSettings?> watchOwnSettings(String uid) {
    requirePathSegment(uid, 'uid');
    return _source
        .watchDocument('users/$uid')
        .map((document) => parseOwnSettingsDocument(document));
  }

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) {
    requirePathSegment(uid, 'uid');
    return _source
        .watchDocument('public_profiles/$uid')
        .map((document) => parsePublicProfileDocument(document));
  }

  @override
  Future<PublicProfile?> readPublicProfile(String uid) async {
    requirePathSegment(uid, 'uid');
    return parsePublicProfileDocument(
      await _source.readDocument('public_profiles/$uid'),
    );
  }

  @override
  Future<List<PublicProfile>> searchPublicProfiles(
    String query, {
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const <PublicProfile>[];
    final boundedLimit = limit.clamp(1, 20);
    final queries = <PublicProfilePrefixQuery>[
      PublicProfilePrefixQuery(
        orderByField: 'username_lower',
        startAt: normalized,
        endAt: '$normalized\uf8ff',
        limit: boundedLimit,
      ),
      PublicProfilePrefixQuery(
        orderByField: 'display_name_lower',
        startAt: normalized,
        endAt: '$normalized\uf8ff',
        limit: boundedLimit,
      ),
    ];
    final snapshots = await Future.wait(
      queries.map(_source.queryPublicProfiles),
    );
    final byUid = <String, PublicProfile>{};
    for (final document in snapshots.expand((documents) => documents)) {
      final profile = parsePublicProfileDocument(document);
      if (profile != null) byUid[profile.uid] = profile;
    }
    final profiles = byUid.values.toList()
      ..sort((left, right) {
        final displayName = left.displayNameLower.compareTo(
          right.displayNameLower,
        );
        if (displayName != 0) return displayName;
        final username = left.usernameLower.compareTo(right.usernameLower);
        if (username != 0) return username;
        return left.uid.compareTo(right.uid);
      });
    return List<PublicProfile>.unmodifiable(profiles.take(boundedLimit));
  }

  @override
  Future<void> ensureOwnProfile({
    required String uid,
    required String displayName,
  }) {
    requirePathSegment(uid, 'uid');
    return _source.createDocumentIfAbsent('users/$uid', <String, Object?>{
      'display_name': displayName,
      'username': '',
      'bio': '',
      'city': '',
      'avatar_path': null,
      'favorite_place_id': null,
      'favorite_flavor_id': null,
      'favorite_flavor_ids': <String>[],
      'profile_visibility': 'private',
      'searchable': false,
      'theme_mode': 'system',
      'default_collection_view': 'list',
      'reduced_motion': false,
      'notifications_enabled': true,
      'points': 0,
    });
  }

  @override
  Future<void> updateProfile(String uid, ProfilePatch patch) async {
    requirePathSegment(uid, 'uid');
    final data = patch.toData();
    if (data.isEmpty) return;
    await _source.updateDocument('users/$uid', data);
  }

  @override
  Future<void> updateThemeMode(String uid, String themeMode) {
    requirePathSegment(uid, 'uid');
    return _source.updateDocument('users/$uid', <String, Object?>{
      'theme_mode': themeMode,
    });
  }

  @override
  Future<void> updateDefaultCollectionView(
    String uid,
    String defaultCollectionView,
  ) {
    requirePathSegment(uid, 'uid');
    if (!const {'list', 'map'}.contains(defaultCollectionView)) {
      throw FormatException(
        'default_collection_view: invalid value $defaultCollectionView',
      );
    }
    return _source.updateDocument('users/$uid', <String, Object?>{
      'default_collection_view': defaultCollectionView,
    });
  }

  @override
  Future<void> updatePrivacy(String uid, {required bool isPrivate}) {
    requirePathSegment(uid, 'uid');
    return _source.updateDocument('users/$uid', <String, Object?>{
      'profile_visibility': isPrivate ? 'private' : 'public',
      'searchable': !isPrivate,
    });
  }
}

final class ProfilePatch {
  const ProfilePatch({
    this.displayName,
    this.username,
    this.bio,
    this.city,
    this.avatarPath = const Keep<String>(),
    this.favoritePlaceId = const Keep<String>(),
    this.favoriteFlavorId = const Keep<String>(),
    this.favoriteFlavorIds,
  });

  final String? displayName;
  final String? username;
  final String? bio;
  final String? city;
  final FieldPatch<String> avatarPath;
  final FieldPatch<String> favoritePlaceId;
  final FieldPatch<String> favoriteFlavorId;
  final List<String>? favoriteFlavorIds;

  Map<String, Object?> toData() {
    if (avatarPath case SetValue<String>(:final value)) {
      requireStoragePath(value, 'avatar_path');
    }
    return <String, Object?>{
      if (displayName != null) 'display_name': displayName,
      if (username != null) 'username': username,
      if (bio != null) 'bio': bio,
      if (city != null) 'city': city,
      ..._fieldPatchData('avatar_path', avatarPath),
      ..._fieldPatchData('favorite_place_id', favoritePlaceId),
      ..._fieldPatchData('favorite_flavor_id', favoriteFlavorId),
      if (favoriteFlavorIds != null)
        'favorite_flavor_ids': List<String>.from(favoriteFlavorIds!),
    };
  }
}

Map<String, Object?> _fieldPatchData<T>(String key, FieldPatch<T> patch) {
  return switch (patch) {
    Keep<T>() => const <String, Object?>{},
    SetValue<T>(:final value) => <String, Object?>{key: value},
    Clear<T>() => <String, Object?>{key: const ProfileDelete()},
  };
}

UserProfile? parseOwnProfileDocument(ProfileDocument? document) {
  if (document == null) return null;
  return parseOrReport<UserProfile>(
    path: 'users/${document.id}',
    parse: () {
      final data = document.data;
      final hasLegacyFields = _legacyProfileKeys.any(data.containsKey);
      final hasCanonicalMigrationFields = _canonicalMigrationKeys.any(
        data.containsKey,
      );
      if (hasLegacyFields && hasCanonicalMigrationFields) {
        return UserProfile.fromMigrationMap(data, document.id);
      }
      if (hasLegacyFields) {
        return UserProfile.fromLegacyMap(data, document.id);
      }
      if (_canonicalRequiredKeys.every(data.containsKey)) {
        return UserProfile.fromMap(data, document.id);
      }
      return UserProfile.fromBackendCompatibleMap(data, document.id);
    },
  );
}

UserSettings? parseOwnSettingsDocument(ProfileDocument? document) {
  if (document == null) return null;
  var data = document.data;
  if (data.containsKey('default_collection_view') &&
      !const {'list', 'map'}.contains(data['default_collection_view'])) {
    parseOrReport<void>(
      path: 'users/${document.id}.default_collection_view',
      parse: () => throw FormatException(
        'default_collection_view: invalid value '
        '${data['default_collection_view']}',
      ),
    );
    data = <String, dynamic>{...data, 'default_collection_view': 'list'};
  }
  return parseOrReport<UserSettings>(
    path: 'users/${document.id}.settings',
    parse: () => UserSettings.fromMap(data),
  );
}

PublicProfile? parsePublicProfileDocument(ProfileDocument? document) {
  if (document == null) return null;
  return parseOrReport<PublicProfile>(
    path: 'public_profiles/${document.id}',
    parse: () => PublicProfile.fromMap(document.data, document.id),
  );
}

const Set<String> _legacyProfileKeys = <String>{
  'photo_url',
  'favorite_gelateria',
  'favorite_flavor',
  'favorite_flavors',
  'friend_uids',
  'default_view',
  'is_private',
  'dismissed_badge_notifications',
  'last_active',
};

const Set<String> _canonicalRequiredKeys = <String>{
  'display_name',
  'username',
  'bio',
  'city',
  'favorite_flavor_ids',
  'points',
};

const Set<String> _canonicalMigrationKeys = <String>{
  'username',
  'bio',
  'city',
  'avatar_path',
  'favorite_place_id',
  'favorite_flavor_id',
  'favorite_flavor_ids',
  'profile_visibility',
};
