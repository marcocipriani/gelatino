import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/user_profile.dart';

void main() {
  Map<String, dynamic> ownerProfile() => <String, dynamic>{
    'display_name': 'Marco',
    'username': 'gelatino',
    'bio': 'Pistacchio first.',
    'city': 'Roma',
    'avatar_path': 'avatars/user-1.jpg',
    'favorite_place_id': 'place-1',
    'favorite_flavor_id': 'pistacchio',
    'favorite_flavor_ids': <String>['pistacchio', 'nocciola'],
    'points': 150,
    'affinity': <String, int>{'legacy-user': 99},
    'theme_mode': 'dark',
  };

  test('parses private owner fields and server-owned points', () {
    final profile = UserProfile.fromMap(ownerProfile(), 'user-1');

    expect(profile.uid, 'user-1');
    expect(profile.displayName, 'Marco');
    expect(profile.avatarPath, 'avatars/user-1.jpg');
    expect(profile.favoriteFlavorIds, <String>['pistacchio', 'nocciola']);
    expect(profile.points, 150);
    expect(profile.level.tier.name, 'Cono');
  });

  test('canonical map omits server settings and legacy social data', () {
    final keys = UserProfile.fromMap(ownerProfile(), 'user-1').toMap().keys;

    expect(keys, <String>{
      'display_name',
      'username',
      'bio',
      'city',
      'avatar_path',
      'favorite_place_id',
      'favorite_flavor_id',
      'favorite_flavor_ids',
    });
    expect(
      keys,
      isNot(
        containsAll(<String>[
          'points',
          'affinity',
          'theme_mode',
          'friend_uids',
        ]),
      ),
    );
  });

  test('FieldPatch keeps sets and clears every nullable profile string', () {
    final profile = UserProfile.fromMap(ownerProfile(), 'user-1');

    final kept = profile.copyWith();
    expect(kept.avatarPath, profile.avatarPath);
    expect(kept.favoritePlaceId, profile.favoritePlaceId);
    expect(kept.favoriteFlavorId, profile.favoriteFlavorId);

    final set = profile.copyWith(
      avatarPath: const SetValue<String>('avatars/new.jpg'),
      favoritePlaceId: const SetValue<String>('place-2'),
      favoriteFlavorId: const SetValue<String>('nocciola'),
    );
    expect(set.avatarPath, 'avatars/new.jpg');
    expect(set.favoritePlaceId, 'place-2');
    expect(set.favoriteFlavorId, 'nocciola');

    final cleared = profile.copyWith(
      avatarPath: const Clear<String>(),
      favoritePlaceId: const Clear<String>(),
      favoriteFlavorId: const Clear<String>(),
    );
    expect(cleared.avatarPath, isNull);
    expect(cleared.favoritePlaceId, isNull);
    expect(cleared.favoriteFlavorId, isNull);
    expect(cleared.toMap(), containsPair('avatar_path', null));
    expect(cleared.toMap(), containsPair('favorite_place_id', null));
    expect(cleared.toMap(), containsPair('favorite_flavor_id', null));

    final legacy = UserProfile.fromLegacyMap(<String, dynamic>{
      'display_name': 'Legacy',
      'points': 4,
      'photo_url': 'https://example.test/legacy.jpg',
    }, 'legacy-user');
    final explicit = legacy
        .copyWith(
          avatarPath: const SetValue<String>('avatars/legacy-user/new.jpg'),
          favoritePlaceId: const Clear<String>(),
          favoriteFlavorId: const SetValue<String>('nocciola'),
          favoriteFlavorIds: const <String>[],
        )
        .toMap();
    expect(explicit['avatar_path'], 'avatars/legacy-user/new.jpg');
    expect(explicit, containsPair('favorite_place_id', null));
    expect(explicit['favorite_flavor_id'], 'nocciola');
    expect(explicit['favorite_flavor_ids'], isEmpty);
  });

  test('rejects malformed points and favorite lists without casts', () {
    expect(
      () => UserProfile.fromMap(ownerProfile()..['points'] = 150.0, 'user-1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => UserProfile.fromMap(
        ownerProfile()..['favorite_flavor_ids'] = <Object>['pistacchio', 2],
        'user-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('public constructor defensively copies compatibility collections', () {
    final flavors = <String>['pistacchio'];
    final friends = <String>['bob'];
    final affinity = <String, int>{'bob': 5};
    final profile = UserProfile(
      uid: 'alice',
      displayName: 'Alice',
      favoriteFlavorIds: flavors,
      friendUids: friends,
      affinity: affinity,
    );

    flavors.add('nocciola');
    friends.add('carol');
    affinity['carol'] = 2;
    expect(profile.favoriteFlavorIds, <String>['pistacchio']);
    expect(profile.friendUids, <String>['bob']);
    expect(profile.affinity, <String, int>{'bob': 5});
    expect(() => profile.friendUids.add('dave'), throwsUnsupportedError);
  });

  test(
    'legacy profile values remain read-only and never enter canonical map',
    () {
      final profile = UserProfile.fromLegacyMap(<String, dynamic>{
        'display_name': 'Legacy',
        'photo_url': 'https://example.test/legacy.jpg',
        'favorite_gelateria': 'Giolitti',
        'favorite_flavor': 'Pistacchio',
        'favorite_flavors': <String>['Pistacchio', 'Nocciola'],
        'points': 4,
      }, 'legacy-user');

      expect(profile.photoUrl, 'https://example.test/legacy.jpg');
      expect(profile.favoriteGelateria, 'Giolitti');
      expect(profile.favoriteFlavor, 'Pistacchio');
      expect(profile.favoriteFlavors, <String>['Pistacchio', 'Nocciola']);
      expect(profile.avatarPath, isNull);
      expect(profile.favoritePlaceId, isNull);
      expect(profile.favoriteFlavorId, isNull);
      expect(profile.favoriteFlavorIds, isEmpty);

      final canonical = profile.copyWith(displayName: 'Updated').toMap();
      expect(canonical, isNot(contains('avatar_path')));
      expect(canonical, isNot(contains('favorite_place_id')));
      expect(canonical, isNot(contains('favorite_flavor_id')));
      expect(canonical, isNot(contains('favorite_flavor_ids')));

      final emptyLegacyFavorites = UserProfile.fromLegacyMap(<String, dynamic>{
        'display_name': 'Legacy',
        'points': 4,
        'favorite_flavors': <String>[],
      }, 'legacy-user').copyWith(favoriteFlavors: <String>['canonical-id']);
      expect(emptyLegacyFavorites.favoriteFlavorIds, <String>['canonical-id']);
      expect(emptyLegacyFavorites.favoriteFlavors, <String>['canonical-id']);
    },
  );

  test('legacy profile still requires display name and points', () {
    expect(
      () => UserProfile.fromLegacyMap(<String, dynamic>{
        'points': 0,
      }, 'legacy-user'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => UserProfile.fromLegacyMap(<String, dynamic>{
        'display_name': 'Legacy',
      }, 'legacy-user'),
      throwsA(isA<FormatException>()),
    );
  });
}
