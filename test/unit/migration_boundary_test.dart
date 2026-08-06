// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in.dart';
import 'package:gelatino/models/legacy_place_social_state.dart';
import 'package:gelatino/models/check_in_parsing.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/providers/user_provider.dart';
import 'package:gelatino/widgets/avatar_image_provider.dart';

class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      FakeDocumentReference('collection/$id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocumentReference implements DocumentReference<Map<String, dynamic>> {
  FakeDocumentReference(this.path);

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const checkInId = 'checkin_123456789012';
  final now = DateTime(2026, 7, 14, 12);

  Map<String, dynamic> legacyProfile() => <String, dynamic>{
    'display_name': 'Legacy',
    'photo_url': 'https://example.test/avatar.jpg',
    'favorite_gelateria': 'Giolitti',
    'favorite_flavor': 'Pistacchio',
    'favorite_flavors': <String>['Pistacchio'],
    'friend_uids': <String>['bob'],
    'default_view': 'list',
    'is_private': false,
    'dismissed_badge_notifications': <String>[],
    'points': 10,
    'affinity': <String, int>{'bob': 5},
    'last_active': Timestamp.fromDate(now),
  };

  Map<String, dynamic> canonicalCheckIn() => <String, dynamic>{
    'user_id': 'alice',
    'user_snapshot': <String, dynamic>{
      'display_name': 'Alice',
      'username': 'alice',
      'avatar_path': null,
    },
    'place_id': 'place-1',
    'place_snapshot': <String, dynamic>{'name': 'Giolitti', 'address': 'Roma'},
    'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'rating': 5,
    'review_text': '',
    'tagged_user_ids': <String>[],
    'photo_storage_path': 'check_ins/alice/$checkInId/1.jpg',
    'created_at': Timestamp.fromDate(now),
    'updated_at': Timestamp.fromDate(now),
    'schema_version': 2,
  };

  Map<String, dynamic> legacyCheckIn() => <String, dynamic>{
    'user_id': 'alice',
    'user_summary': <String, dynamic>{'username': 'Alice', 'avatar_url': null},
    'place_id': 'place-1',
    'place_name': 'Giolitti',
    'photo_url': 'https://example.test/photo.jpg',
    'is_live_photo': false,
    'review_text': null,
    'rating': 5,
    'flavors': <Map<String, dynamic>>[],
    'liked_by_uids': <String>[],
    'wishlisted_by_uids': <String>[],
    'location': null,
    'created_at': Timestamp.fromDate(now),
    'tagged_user_uids': <String>[],
    'tagged_user_names': <String, String>{},
  };

  test(
    'profile boundary explicitly reads legacy and backend-valid sparse docs',
    () {
      final legacy = parseCurrentUserProfileSnapshot(
        FakeDocumentSnapshot('legacy-user', legacyProfile()),
      );
      final sparse = parseCurrentUserProfileSnapshot(
        FakeDocumentSnapshot('new-user', <String, dynamic>{'points': 0}),
      );

      expect(legacy?.friendUids, <String>['bob']);
      expect(legacy?.avatarPath, isNull);
      expect(legacy?.photoUrl, 'https://example.test/avatar.jpg');
      expect(legacy?.favoritePlaceId, isNull);
      expect(legacy?.favoriteGelateria, 'Giolitti');
      expect(sparse?.displayName, '');
      expect(sparse?.points, 0);
    },
  );

  test(
    'canonical avatar paths never become network URLs but legacy URLs do',
    () {
      final previous = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      final canonical = parseCurrentUserProfileSnapshot(
        FakeDocumentSnapshot('new-user', <String, dynamic>{
          'points': 0,
          'avatar_path': 'https://example.test/canonical.jpg',
        }),
      );
      final legacy = parseCurrentUserProfileSnapshot(
        FakeDocumentSnapshot('legacy-user', legacyProfile()),
      );

      expect(canonical, isNull);
      expect(errors, hasLength(1));
      expect(legacy?.avatarPath, isNull);
      expect(legacy?.photoUrl, 'https://example.test/avatar.jpg');
      expect(avatarImageProvider(legacy?.photoUrl), isA<NetworkImage>());
    },
  );

  test('profile boundary preserves canonical fields in mixed documents', () {
    final mixed = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('mixed-user', <String, dynamic>{
        ...legacyProfile(),
        'username': 'canonical-user',
        'bio': 'Canonical bio',
        'city': 'Roma',
        'avatar_path': 'avatars/mixed-user/profile.jpg',
        'favorite_place_id': 'place-2',
        'favorite_flavor_id': 'nocciola',
        'favorite_flavor_ids': <String>['nocciola', 'limone'],
        'profile_visibility': 'friends',
      }),
    );

    expect(mixed, isNotNull);
    expect(mixed?.username, 'canonical-user');
    expect(mixed?.bio, 'Canonical bio');
    expect(mixed?.city, 'Roma');
    expect(mixed?.avatarPath, 'avatars/mixed-user/profile.jpg');
    expect(mixed?.photoUrl, 'avatars/mixed-user/profile.jpg');
    expect(mixed?.favoritePlaceId, 'place-2');
    expect(mixed?.favoriteGelateria, 'place-2');
    expect(mixed?.favoriteFlavorId, 'nocciola');
    expect(mixed?.favoriteFlavor, 'nocciola');
    expect(mixed?.favoriteFlavorIds, <String>['nocciola', 'limone']);
    expect(mixed?.favoriteFlavors, <String>['nocciola', 'limone']);
    expect(mixed?.friendUids, <String>['bob']);
    expect(mixed?.isPrivate, isFalse);

    final canonical = mixed!.copyWith(displayName: 'Updated').toMap();
    expect(canonical['display_name'], 'Updated');
    expect(canonical['username'], 'canonical-user');
    expect(canonical['bio'], 'Canonical bio');
    expect(canonical['city'], 'Roma');
    expect(canonical['avatar_path'], 'avatars/mixed-user/profile.jpg');
    expect(canonical['favorite_place_id'], 'place-2');
    expect(canonical['favorite_flavor_id'], 'nocciola');
    expect(canonical['favorite_flavor_ids'], <String>['nocciola', 'limone']);
    expect(canonical.values, isNot(contains('Giolitti')));
    expect(canonical.values, isNot(contains('Pistacchio')));
    expect(
      canonical.values,
      isNot(contains('https://example.test/avatar.jpg')),
    );
  });

  test('display-only legacy update omits untouched canonical optionals', () {
    final original = legacyProfile();
    final legacy = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('legacy-user', original),
    )!;
    final update = legacy.copyWith(displayName: 'Updated Legacy').toMap();

    expect(update, isNot(contains('avatar_path')));
    expect(update, isNot(contains('favorite_place_id')));
    expect(update, isNot(contains('favorite_flavor_id')));
    expect(update, isNot(contains('favorite_flavor_ids')));

    final reparsed = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('legacy-user', <String, dynamic>{
        ...original,
        ...update,
      }),
    );
    expect(reparsed?.displayName, 'Updated Legacy');
    expect(reparsed?.avatarPath, isNull);
    expect(reparsed?.photoUrl, 'https://example.test/avatar.jpg');
    expect(reparsed?.favoritePlaceId, isNull);
    expect(reparsed?.favoriteGelateria, 'Giolitti');
    expect(reparsed?.favoriteFlavorId, isNull);
    expect(reparsed?.favoriteFlavor, 'Pistacchio');
    expect(reparsed?.favoriteFlavorIds, isEmpty);
    expect(reparsed?.favoriteFlavors, <String>['Pistacchio']);
  });

  test('profile migration boundary rejects malformed optional fields', () {
    final previous = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final invalidFavorite = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('new-user', <String, dynamic>{
        'points': 0,
        'favorite_place_id': 'invalid/id',
      }),
    );
    final nullLegacyList = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('legacy-user', <String, dynamic>{
        ...legacyProfile(),
        'dismissed_badge_notifications': null,
      }),
    );
    final malformedMixed = parseCurrentUserProfileSnapshot(
      FakeDocumentSnapshot('mixed-user', <String, dynamic>{
        ...legacyProfile(),
        'username': 7,
      }),
    );

    expect(invalidFavorite, isNull);
    expect(nullLegacyList, isNull);
    expect(malformedMixed, isNull);
    expect(errors, hasLength(3));
  });

  test(
    'new profile create contains only the Rules-required points initializer',
    () {
      final data = UserProfile(
        uid: 'new-user',
        displayName: 'Nuovo',
      ).toInitialCreateMap();

      expect(data['points'], 0);
      expect(data, isNot(contains('affinity')));
      expect(data.keys, <String>{
        'display_name',
        'username',
        'bio',
        'city',
        'avatar_path',
        'favorite_place_id',
        'favorite_flavor_id',
        'favorite_flavor_ids',
        'points',
      });
    },
  );

  test(
    'check-in boundary selects v2 or legacy and reports malformed documents',
    () {
      final previous = FlutterError.onError;
      final errors = <FlutterErrorDetails>[];
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      final parsed = parseCheckInSnapshots(
        <DocumentSnapshot<Map<String, dynamic>>>[
          FakeDocumentSnapshot(checkInId, canonicalCheckIn()),
          FakeDocumentSnapshot('legacy_1234567890123', legacyCheckIn()),
          FakeDocumentSnapshot('malformed_1234567890', <String, dynamic>{
            'schema_version': 3,
          }),
        ],
      );

      expect(parsed.map((item) => item.schemaVersion), <int>[2, 1]);
      expect(errors, hasLength(1));
      expect(errors.single.context.toString(), contains('check_ins/malformed'));
    },
  );

  test('canonical place and migration-only social adapter are separate', () {
    final data = <String, dynamic>{
      'name': 'Giolitti',
      'address': 'Roma',
      'location': const GeoPoint(41.9, 12.5),
      'geohash': '',
      'created_at': Timestamp.fromDate(now),
      'added_by_uid': null,
      'liked_by_uids': <String>['alice'],
      'favorited_by_uids': <String>[],
      'wishlisted_by_uids': <String>[],
    };

    final snapshot = FakeDocumentSnapshot('place-1', data);
    final place = Place.fromFirestore(snapshot);
    final social = LegacyPlaceSocialState.fromFirestore(snapshot);
    expect(place.id, 'place-1');
    expect(social.likedByUids, <String>['alice']);
  });

  test('legacy place arrays default only when absent', () {
    final base = <String, dynamic>{
      'name': 'Giolitti',
      'address': 'Roma',
      'location': const GeoPoint(41.9, 12.5),
      'geohash': '',
      'created_at': Timestamp.fromDate(now),
      'added_by_uid': null,
      'liked_by_uids': <String>['alice'],
    };

    final partial = LegacyPlaceSocialState.fromFirestore(
      FakeDocumentSnapshot('place-1', base),
    );
    expect(partial.favoritedByUids, isEmpty);
    expect(partial.wishlistedByUids, isEmpty);

    expect(
      () => LegacyPlaceSocialState.fromFirestore(
        FakeDocumentSnapshot('place-2', <String, dynamic>{
          ...base,
          'liked_by_uids': null,
        }),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('canonical flavor snapshot accepts optional color_hex field', () {
    final previous = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    // Valid: with color_hex present
    final withColor = CheckIn.fromFirestore(
      FakeDocumentSnapshot(checkInId, <String, dynamic>{
        ...canonicalCheckIn(),
        'flavors': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pistacchio',
            'name': 'Pistacchio',
            'color_hex': '#93C572',
          },
        ],
      }),
    );
    expect(withColor.flavors.first.colorHex, '#93C572');

    // Valid: with color_hex null
    final withNullColor = CheckIn.fromFirestore(
      FakeDocumentSnapshot(checkInId, <String, dynamic>{
        ...canonicalCheckIn(),
        'flavors': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pistacchio',
            'name': 'Pistacchio',
            'color_hex': null,
          },
        ],
      }),
    );
    expect(withNullColor.flavors.first.colorHex, isNull);

    // Valid: without color_hex field
    final withoutColor = CheckIn.fromFirestore(
      FakeDocumentSnapshot(checkInId, <String, dynamic>{
        ...canonicalCheckIn(),
        'flavors': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pistacchio',
            'name': 'Pistacchio',
          },
        ],
      }),
    );
    expect(withoutColor.flavors.first.colorHex, isNull);

    // Invalid: malformed color_hex
    expect(
      () => CheckIn.fromFirestore(
        FakeDocumentSnapshot(checkInId, <String, dynamic>{
          ...canonicalCheckIn(),
          'flavors': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'pistacchio',
              'name': 'Pistacchio',
              'color_hex': 'red',
            },
          ],
        }),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(errors, isEmpty);
  });
}
