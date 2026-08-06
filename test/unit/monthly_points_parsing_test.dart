import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';

/// A complete, valid `public_profiles/{uid}` projection (all keys of
/// `_publicProfileKeys` in public_profile.dart), following the fixture
/// pattern in public_profile_test.dart.
Map<String, dynamic> validPublicProfileData() => <String, dynamic>{
  'uid': 'u1',
  'display_name': 'Marco',
  'display_name_lower': 'marco',
  'username': 'gelatino',
  'username_lower': 'gelatino',
  'avatar_path': 'avatars/u1.jpg',
  'bio': 'Pistacchio first.',
  'city': 'Roma',
  'favorite_place_id': 'place-1',
  'favorite_flavor_id': 'pistacchio',
  'favorite_flavor_ids': <String>['pistacchio', 'nocciola'],
  'profile_visibility': 'friends',
  'searchable': false,
  'points': 150,
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 14, 10)),
};

/// A complete, valid `users/{uid}` owner document, following the fixture
/// pattern in user_profile_test.dart.
Map<String, dynamic> validUserProfileData() => <String, dynamic>{
  'display_name': 'Marco',
  'username': 'gelatino',
  'bio': 'Pistacchio first.',
  'city': 'Roma',
  'avatar_path': 'avatars/u1.jpg',
  'favorite_place_id': 'place-1',
  'favorite_flavor_id': 'pistacchio',
  'favorite_flavor_ids': <String>['pistacchio', 'nocciola'],
  'points': 150,
};

void main() {
  group('PublicProfile.monthlyPoints', () {
    test('monthly_points parses and defaults to empty', () {
      final withField = PublicProfile.fromMap({
        ...validPublicProfileData(),
        'monthly_points': {'2026-07': 25},
      }, 'u1');
      expect(withField.monthlyPoints, {'2026-07': 25});

      final without = PublicProfile.fromMap(validPublicProfileData(), 'u1');
      expect(without.monthlyPoints, isEmpty);
    });

    test('invalid monthly_points throws', () {
      for (final bad in [
        {'2026-7': 1},
        {'2026-07': -1},
        {'2026-07': 'x'},
        'not-a-map',
      ]) {
        expect(
          () => PublicProfile.fromMap({
            ...validPublicProfileData(),
            'monthly_points': bad,
          }, 'u1'),
          throwsFormatException,
        );
      }
    });

    test('monthlyPoints map is unmodifiable', () {
      final profile = PublicProfile.fromMap({
        ...validPublicProfileData(),
        'monthly_points': {'2026-07': 25},
      }, 'u1');
      expect(
        () => profile.monthlyPoints['2026-08'] = 1,
        throwsUnsupportedError,
      );
    });
  });

  group('UserProfile.monthlyPoints', () {
    test('fromMap parses and defaults to empty', () {
      final withField = UserProfile.fromMap({
        ...validUserProfileData(),
        'monthly_points': {'2026-07': 25},
      }, 'u1');
      expect(withField.monthlyPoints, {'2026-07': 25});

      final without = UserProfile.fromMap(validUserProfileData(), 'u1');
      expect(without.monthlyPoints, isEmpty);
    });

    test('fromMap throws on invalid monthly_points', () {
      expect(
        () => UserProfile.fromMap({
          ...validUserProfileData(),
          'monthly_points': 'not-a-map',
        }, 'u1'),
        throwsFormatException,
      );
    });

    test('fromLegacyMap parses and defaults to empty', () {
      final withField = UserProfile.fromLegacyMap({
        'display_name': 'Legacy',
        'points': 4,
        'monthly_points': {'2026-07': 3},
      }, 'legacy-user');
      expect(withField.monthlyPoints, {'2026-07': 3});

      final without = UserProfile.fromLegacyMap({
        'display_name': 'Legacy',
        'points': 4,
      }, 'legacy-user');
      expect(without.monthlyPoints, isEmpty);
    });

    test('fromMigrationMap parses and defaults to empty', () {
      final withField = UserProfile.fromMigrationMap({
        'display_name': 'Migrated',
        'points': 4,
        'monthly_points': {'2026-07': 7},
      }, 'migration-user');
      expect(withField.monthlyPoints, {'2026-07': 7});

      final without = UserProfile.fromMigrationMap({
        'display_name': 'Migrated',
        'points': 4,
      }, 'migration-user');
      expect(without.monthlyPoints, isEmpty);
    });

    test('fromBackendCompatibleMap parses and defaults to empty', () {
      final withField = UserProfile.fromBackendCompatibleMap({
        'points': 4,
        'monthly_points': {'2026-07': 9},
      }, 'sparse-user');
      expect(withField.monthlyPoints, {'2026-07': 9});

      final without = UserProfile.fromBackendCompatibleMap({
        'points': 4,
      }, 'sparse-user');
      expect(without.monthlyPoints, isEmpty);
    });

    test('copyWith preserves monthlyPoints', () {
      final profile = UserProfile.fromMap({
        ...validUserProfileData(),
        'monthly_points': {'2026-07': 25},
      }, 'u1');
      final copy = profile.copyWith(displayName: 'Updated');
      expect(copy.monthlyPoints, {'2026-07': 25});
    });
  });
}
