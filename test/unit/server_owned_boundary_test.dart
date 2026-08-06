import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'server-owned models and check-ins expose no direct write serializer',
    () {
      for (final path in <String>[
        'lib/models/public_profile.dart',
        'lib/models/friendship.dart',
        'lib/models/feed_item.dart',
        'lib/models/check_in.dart',
        'lib/models/gelato_invite.dart',
        'lib/models/place_state.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('Map<String, dynamic> toMap()')),
          reason: path,
        );
        expect(source, isNot(contains('toLegacyMap')), reason: path);
      }
    },
  );

  test(
    'runtime has no global check-in provider, import or collection scan',
    () {
      expect(
        File('lib/providers/check_ins_provider.dart').existsSync(),
        isFalse,
      );
      final runtime = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in runtime) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('checkInsProvider')), reason: file.path);
        expect(
          source,
          isNot(matches(RegExp(r'''collection\(['"]check_ins['"]\)'''))),
          reason: file.path,
        );
        expect(
          source,
          isNot(contains('check_ins_provider.dart')),
          reason: file.path,
        );
      }
    },
  );

  test('social runtime uses canonical relationships without legacy arrays', () {
    final source = File('lib/providers/user_provider.dart').readAsStringSync();
    final friends = File('lib/screens/friends_screen.dart').readAsStringSync();

    expect(source, isNot(contains('FieldValue.arrayUnion')));
    expect(source, isNot(contains('FieldValue.arrayRemove')));
    expect(source, isNot(contains('friendUids')));
    expect(source, isNot(contains('.affinity')));
    expect(friends, contains('friendshipRepositoryProvider'));
    expect(friends, contains('gelatoInviteRepositoryProvider'));
  });

  test('place actions use private state without catalog social writes', () {
    final source = <String>[
      File('lib/providers/place_providers.dart').readAsStringSync(),
      File('lib/repositories/place_repository.dart').readAsStringSync(),
      File('lib/repositories/place_state_repository.dart').readAsStringSync(),
    ].join('\n');

    expect(source, isNot(contains('FieldValue.arrayUnion')));
    expect(source, isNot(contains('FieldValue.arrayRemove')));
    expect(source, isNot(contains('bootstrapRomePlaces')));
    expect(source, isNot(contains('rootBundle')));
    expect(source, isNot(contains('.update(')));
    expect(source, contains('users/\$uid/place_states/\$placeId'));
    expect(source, contains('SetOptions(merge: true)'));
  });

  test('place detail uses only server-owned aggregate data', () {
    final screen = File(
      'lib/screens/place_detail_screen.dart',
    ).readAsStringSync();
    final flavors = File('lib/widgets/flavors_manager.dart').readAsStringSync();
    final aggregates = <String>[
      File('lib/models/place_aggregate.dart').readAsStringSync(),
      File(
        'lib/repositories/place_aggregate_repository.dart',
      ).readAsStringSync(),
      File('lib/providers/place_aggregate_providers.dart').readAsStringSync(),
    ].join('\n');

    expect(aggregates, contains('place_aggregates/\$placeId'));
    expect(screen, contains('placeAggregateProvider'));
    expect(screen, isNot(contains('timelineProvider')));
    expect(screen, isNot(contains('FeedItem')));
    expect(screen, isNot(contains('CheckIn')));
    expect(screen, isNot(contains('checkInsProvider')));
    expect(screen, isNot(contains('Ancora nessun check-in registrato')));
    expect(flavors, isNot(contains('checkInsProvider')));
    expect(flavors, isNot(contains("value: 'recent'")));
  });

  test('global check-in badge derivation is removed', () {
    final users = File('lib/providers/user_provider.dart').readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(users, isNot(contains('unlockedBadgesProvider')));
    expect(main, isNot(contains('unlockedBadgesProvider')));
    expect(main, isNot(contains('ref.listen<List<String>>')));
  });

  test('profile settings use scoped repositories without activity writes', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final settings = File(
      'lib/screens/settings_screen.dart',
    ).readAsStringSync();
    final places = File('lib/screens/places_tab.dart').readAsStringSync();

    expect(main, isNot(contains("'last_active'")));
    expect(main, isNot(contains('dismissedBadgeNotifications:')));
    expect(profile, isNot(contains('copyWith(defaultView:')));
    expect(profile, isNot(contains('ownSettingsProvider')));
    expect(profile, isNot(contains('updateDefaultCollectionView')));
    expect(settings, contains('ownSettingsProvider'));
    expect(settings, contains('updateDefaultCollectionView'));
    expect(settings, contains('updatePrivacy'));
    expect(profile, isNot(contains('updateSettings')));
    expect(profile, isNot(contains('Disponibile prossimamente')));
    expect(places, contains('defaultCollectionViewProvider'));
  });

  test('Task 3 and Task 8 global providers are removed', () {
    final users = File('lib/providers/user_provider.dart').readAsStringSync();

    expect(users, isNot(contains('TODO(Task 3)')));
    expect(users, contains('publicProfileProvider'));
    expect(File('lib/providers/check_ins_provider.dart').existsSync(), isFalse);
  });

  test(
    'avatar callsites render canonical paths through authenticated widget',
    () {
      final callsites = <String, List<String>>{
        'lib/widgets/authenticated_shell.dart': <String>[
          'lib/widgets/authenticated_shell.dart',
        ],
        'lib/screens/profile_screen.dart': <String>[
          'lib/screens/profile_screen.dart',
        ],
        'lib/screens/friends_screen.dart': <String>[
          'lib/screens/friends_screen.dart',
          'lib/screens/friends/friends_sections.dart',
        ],
        'Timeline modules': <String>[
          'lib/screens/timeline_screen.dart',
          'lib/widgets/timeline/timeline_editorial_card.dart',
          'lib/widgets/timeline/friends_activity_sidebar.dart',
        ],
        'lib/widgets/edit_profile_dialog.dart': <String>[
          'lib/widgets/edit_profile_dialog.dart',
        ],
      };
      for (final entry in callsites.entries) {
        final source = entry.value
            .map((path) => File(path).readAsStringSync())
            .join('\n');
        expect(
          RegExp(r'(?<!Cached)NetworkImage\(').hasMatch(source),
          isFalse,
          reason: entry.key,
        );
        expect(source, contains('AuthenticatedAvatar('), reason: entry.key);
        expect(
          source,
          isNot(contains('avatarImageProvider(')),
          reason: entry.key,
        );
      }
      final placeDetail = File(
        'lib/screens/place_detail_screen.dart',
      ).readAsStringSync();
      expect(placeDetail, isNot(contains('AuthenticatedAvatar(')));
      expect(placeDetail, isNot(contains('avatarImageProvider(')));
      final avatarWidget = File(
        'lib/widgets/avatar_image_provider.dart',
      ).readAsStringSync();
      expect(avatarWidget, contains('mediaBytesProvider'));
      expect(avatarWidget, contains('avatarMediaMaxBytes'));
      expect(avatarWidget, contains('MemoryImage('));
      expect(avatarWidget, contains('NetworkImage(source)'));
      expect(avatarWidget, isNot(contains('getDownloadURL')));
    },
  );

  test(
    'check-in runtime delegates staged publication without legacy writes',
    () {
      final screen = File(
        'lib/screens/check_in_screen.dart',
      ).readAsStringSync();
      final screenFlow = File(
        'lib/screens/check_in/check_in_flow.dart',
      ).readAsStringSync();
      final flow = File(
        'lib/providers/check_in_flow_provider.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/repositories/check_in_repository.dart',
      ).readAsStringSync();
      final timeline = File(
        'lib/screens/timeline_screen.dart',
      ).readAsStringSync();

      expect(screenFlow, contains('checkInFlowProvider'));
      expect(screen + screenFlow, isNot(contains('checkInsProvider')));
      expect(flow, contains('uploadStagingPhoto'));
      expect(repository, contains("call('createCheckIn'"));
      expect(repository, contains("call('deleteCheckIn'"));
      for (final source in [screen, screenFlow, flow, repository, timeline]) {
        expect(source, isNot(contains('uploadCheckInPhoto')));
        expect(source, isNot(contains('CheckInService')));
        expect(source, isNot(contains('toggleLike')));
        expect(source, isNot(contains('toggleWishlist')));
        expect(source, isNot(contains('addPoints')));
        expect(source, isNot(contains('incrementAffinity')));
      }
    },
  );
}
