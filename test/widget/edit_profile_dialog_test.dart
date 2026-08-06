import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/models/user_settings.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/repositories/profile_repository.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/edit_profile_dialog.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

void main() {
  testWidgets('saves only editable personal profile data', (tester) async {
    final repository = RecordingProfileRepository();
    final profile = UserProfile(
      uid: 'alice',
      displayName: 'Alice',
      favoritePlaceId: 'place-1',
      favoriteFlavorId: 'pistacchio',
      isPrivate: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          ownSettingsProvider.overrideWith(
            (ref) => Stream<UserSettings?>.value(_privateSettings),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: EditProfileDialog(profile: profile)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.textContaining('Task 3'), findsNothing);
    expect(find.textContaining('raccolta personale'), findsOneWidget);
    expect(find.textContaining('Impostazioni profilo'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Alice B');
    await tester.tap(find.text('Salva'));
    await tester.pump();

    expect(repository.profileUpdates.single.$1, 'alice');
    expect(repository.profileUpdates.single.$2.displayName, 'Alice B');
    expect(repository.privacyUpdates, isEmpty);
  });

  testWidgets('avatar retry overwrites one stable version path', (
    tester,
  ) async {
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _AvatarPicker();
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);
    final repository = RecordingProfileRepository();
    final storage = _AvatarStorageGateway()..failNext = true;
    final profile = UserProfile(uid: 'alice', displayName: 'Alice');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(storage),
          ),
          ownSettingsProvider.overrideWith(
            (ref) => Stream<UserSettings?>.value(_privateSettings),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: EditProfileDialog(profile: profile)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.byType(CircleAvatar),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salva'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(repository.profileUpdates, isEmpty);

    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salva'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(storage.paths, hasLength(2));
    expect(storage.paths.toSet(), hasLength(1));
    expect(storage.paths.first, startsWith('avatars/alice/'));
    expect(
      repository.profileUpdates.single.$2.avatarPath,
      isA<SetValue<String>>(),
    );
  });
}

const _privateSettings = UserSettings(
  themeMode: 'system',
  defaultCollectionView: 'list',
  reducedMotion: false,
  notificationsEnabled: true,
  profileVisibility: 'private',
  searchable: false,
);

final class RecordingProfileRepository implements ProfileRepository {
  final List<(String, ProfilePatch)> profileUpdates = [];
  final List<(String, bool)> privacyUpdates = [];

  @override
  Future<void> updateProfile(String uid, ProfilePatch patch) async {
    profileUpdates.add((uid, patch));
  }

  @override
  Future<void> updatePrivacy(String uid, {required bool isPrivate}) async {
    privacyUpdates.add((uid, isPrivate));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AvatarPicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
    name: 'avatar.png',
    mimeType: 'image/png',
  );
}

final class _AvatarStorageGateway implements StorageObjectGateway {
  final List<String> paths = [];
  bool failNext = false;

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    paths.add(path);
    if (failNext) {
      failNext = false;
      throw StateError('network');
    }
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async => null;
}
