import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/user_settings.dart';

void main() {
  test('parses persisted owner settings', () {
    final settings = UserSettings.fromMap(<String, dynamic>{
      'theme_mode': 'dark',
      'default_collection_view': 'map',
      'reduced_motion': true,
      'notifications_enabled': false,
      'profile_visibility': 'friends',
      'searchable': false,
    });

    expect(settings.themeMode, 'dark');
    expect(settings.defaultCollectionView, 'map');
    expect(settings.reducedMotion, isTrue);
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.profileVisibility, 'friends');
    expect(settings.searchable, isFalse);
  });

  test('uses documented defaults only when fields are absent', () {
    final settings = UserSettings.fromMap(<String, dynamic>{});

    expect(settings.themeMode, 'system');
    expect(settings.defaultCollectionView, 'list');
    expect(settings.reducedMotion, isFalse);
    expect(settings.notificationsEnabled, isTrue);
    expect(settings.profileVisibility, 'private');
    expect(settings.searchable, isFalse);
  });

  test('rejects invalid enum values and malformed booleans', () {
    expect(
      () => UserSettings.fromMap(<String, dynamic>{'theme_mode': 'sepia'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => UserSettings.fromMap(<String, dynamic>{'searchable': 1}),
      throwsA(isA<FormatException>()),
    );
    for (final key in <String>[
      'theme_mode',
      'default_collection_view',
      'profile_visibility',
      'reduced_motion',
      'notifications_enabled',
      'searchable',
    ]) {
      expect(
        () => UserSettings.fromMap(<String, dynamic>{key: null}),
        throwsA(isA<FormatException>()),
        reason: key,
      );
    }
  });

  test('serializes only owner settings fields', () {
    final keys = UserSettings.fromMap(<String, dynamic>{}).toMap().keys;

    expect(keys, <String>{
      'theme_mode',
      'default_collection_view',
      'reduced_motion',
      'notifications_enabled',
      'profile_visibility',
      'searchable',
    });
  });
}
