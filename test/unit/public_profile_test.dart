import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';

void main() {
  final updatedAt = DateTime(2026, 7, 14, 10);

  Map<String, dynamic> validProfile() => <String, dynamic>{
    'uid': 'user-1',
    'display_name': 'Marco',
    'display_name_lower': 'marco',
    'username': 'gelatino',
    'username_lower': 'gelatino',
    'avatar_path': 'avatars/user-1.jpg',
    'bio': 'Pistacchio first.',
    'city': 'Roma',
    'favorite_place_id': 'place-1',
    'favorite_flavor_id': 'pistacchio',
    'favorite_flavor_ids': <String>['pistacchio', 'nocciola'],
    'profile_visibility': 'friends',
    'searchable': false,
    'points': 150,
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  test('parses the exact public profile projection', () {
    final profile = PublicProfile.fromMap(validProfile(), 'user-1');

    expect(profile.uid, 'user-1');
    expect(profile.displayName, 'Marco');
    expect(profile.favoriteFlavorIds, <String>['pistacchio', 'nocciola']);
    expect(profile.points, 150);
    expect(profile.updatedAt, updatedAt);
    expect(profile.level.tier.name, 'Cono');
  });

  test('rejects fields outside the public privacy allowlist', () {
    final privateData = validProfile()..['email'] = 'private@example.test';
    expect(
      () => PublicProfile.fromMap(privateData, 'user-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects mismatched IDs and invalid privacy or points', () {
    expect(
      () => PublicProfile.fromMap(validProfile(), 'other-user'),
      throwsA(isA<FormatException>()),
    );

    final badVisibility = validProfile()..['profile_visibility'] = 'everyone';
    expect(
      () => PublicProfile.fromMap(badVisibility, 'user-1'),
      throwsA(isA<FormatException>()),
    );

    final badPoints = validProfile()..['points'] = -1;
    expect(
      () => PublicProfile.fromMap(badPoints, 'user-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects malformed timestamps and favorite ID lists', () {
    final badTimestamp = validProfile()
      ..['updated_at'] = updatedAt.toIso8601String();
    expect(
      () => PublicProfile.fromMap(badTimestamp, 'user-1'),
      throwsA(isA<FormatException>()),
    );

    final badFavorites = validProfile()
      ..['favorite_flavor_ids'] = <Object>['pistacchio', 7];
    expect(
      () => PublicProfile.fromMap(badFavorites, 'user-1'),
      throwsA(isA<FormatException>()),
    );
  });
}
