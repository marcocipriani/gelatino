import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/avatar_image_provider.dart';

void main() {
  test('avatar provider accepts only absolute HTTP URLs', () {
    expect(avatarImageProvider(null), isNull);
    expect(avatarImageProvider(''), isNull);
    expect(avatarImageProvider('avatars/alice/profile.jpg'), isNull);
    expect(avatarImageProvider('ftp://example.test/avatar.jpg'), isNull);
    expect(avatarImageProvider('https:///missing-host.jpg'), isNull);

    final http = avatarImageProvider('http://example.test/avatar.jpg');
    final https = avatarImageProvider('https://example.test/avatar.jpg');
    expect(http, isA<NetworkImage>());
    expect(https, isA<NetworkImage>());
    expect((https! as NetworkImage).url, 'https://example.test/avatar.jpg');
  });

  testWidgets('canonical avatar path renders authenticated MemoryImage', (
    tester,
  ) async {
    final gateway = _AvatarStorageGateway(readResult: _onePixelPng());

    await tester.pumpWidget(_app('avatars/alice/version.jpg', gateway));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<MemoryImage>());
    expect(gateway.readPaths, <String>['avatars/alice/version.jpg']);
  });

  testWidgets('legacy URL renders NetworkImage without Storage read', (
    tester,
  ) async {
    final gateway = _AvatarStorageGateway();
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(_app('https://example.test/avatar.jpg', gateway));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(gateway.readPaths, isEmpty);
  });

  testWidgets('missing authenticated avatar renders fallback', (tester) async {
    final gateway = _AvatarStorageGateway();

    await tester.pumpWidget(_app('avatars/alice/missing.jpg', gateway));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('authenticated avatar read error renders fallback', (
    tester,
  ) async {
    final gateway = _AvatarStorageGateway(readError: StateError('network'));

    await tester.pumpWidget(_app('avatars/alice/error.jpg', gateway));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}

Widget _app(String source, _AvatarStorageGateway gateway) => ProviderScope(
  overrides: [
    storageServiceProvider.overrideWithValue(
      StorageService.forTesting(gateway),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(body: AuthenticatedAvatar(source: source, radius: 24)),
  ),
);

final class _AvatarStorageGateway implements StorageObjectGateway {
  _AvatarStorageGateway({this.readResult, this.readError});

  final Uint8List? readResult;
  final Object? readError;
  final List<String> readPaths = <String>[];

  @override
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata) =>
      throw UnimplementedError();

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    readPaths.add(path);
    if (readError case final error?) throw error;
    return readResult;
  }
}

Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
