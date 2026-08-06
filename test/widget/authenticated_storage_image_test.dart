import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/providers/media_provider.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/authenticated_check_in_photo.dart';
import 'package:gelatino/widgets/authenticated_storage_image.dart';
import 'package:gelatino/widgets/avatar_image_provider.dart';
import 'package:gelatino/widgets/skeleton_loader.dart';

void main() {
  testWidgets('loader preserves geometry and renders semantic memory image', (
    tester,
  ) async {
    final gateway = _ImageGateway()..result = _onePixelPng();
    await tester.pumpWidget(
      _app(
        gateway,
        const AuthenticatedStorageImage(
          path: 'check_ins/alice/id/1.jpg',
          maxBytes: 123,
          semanticLabel: 'Gelato al pistacchio',
          width: 280,
          height: 180,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AuthenticatedStorageImage)),
      const Size(280, 180),
    );
    expect(find.bySemanticsLabel('Gelato al pistacchio'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(gateway.reads.single, (
      path: 'check_ins/alice/id/1.jpg',
      maxBytes: 123,
    ));
  });

  testWidgets(
    'null dimensions stay finite on unbounded axes while loading and loaded',
    (tester) async {
      final pending = Completer<Uint8List?>();
      final gateway = _ImageGateway()..pending = pending;
      await tester.pumpWidget(
        _app(
          gateway,
          const Column(
            children: [
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AuthenticatedStorageImage(
                      path: 'check_ins/alice/id/horizontal.jpg',
                      maxBytes: 123,
                      semanticLabel: 'Orizzontale',
                      height: 80,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AuthenticatedStorageImage(
                      path: 'check_ins/alice/id/vertical.jpg',
                      maxBytes: 123,
                      semanticLabel: 'Verticale',
                      width: 80,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonBox), findsNWidgets(2));

      pending.complete(_onePixelPng());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNWidgets(2));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.width, isNot(double.infinity));
        expect(image.height, isNot(double.infinity));
      }
    },
  );

  testWidgets('error fallback keeps geometry and retries only its request', (
    tester,
  ) async {
    final gateway = _ImageGateway()..error = StateError('offline/private');
    await tester.pumpWidget(
      _app(
        gateway,
        const AuthenticatedStorageImage(
          path: 'check_ins/alice/id/2.jpg',
          maxBytes: 123,
          semanticLabel: 'Foto check-in',
          width: 240,
          height: 140,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Transient failures are retried twice (1s, 2s backoff) before the manual
    // fallback appears, so the geometry must hold through the retry window and
    // the error must still never leak into the UI.
    expect(
      tester.getSize(find.byType(AuthenticatedStorageImage)),
      const Size(240, 140),
    );
    expect(find.textContaining('offline/private'), findsNothing);
    expect(find.byTooltip('Riprova immagine'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(gateway.reads, hasLength(3));
    expect(
      tester.getSize(find.byType(AuthenticatedStorageImage)),
      const Size(240, 140),
    );
    expect(find.textContaining('offline/private'), findsNothing);
    expect(find.byTooltip('Riprova immagine'), findsOneWidget);

    gateway
      ..error = null
      ..result = _onePixelPng();
    await tester.tap(find.byTooltip('Riprova immagine'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(gateway.reads, hasLength(4));
  });

  testWidgets('corrupt bytes keep fallback geometry and can retry valid data', (
    tester,
  ) async {
    final gateway = _ImageGateway()..result = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(
      _app(
        gateway,
        const AuthenticatedStorageImage(
          path: 'check_ins/alice/id/corrupt.jpg',
          maxBytes: 123,
          semanticLabel: 'Foto corrotta',
          width: 240,
          height: 140,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Riprova immagine'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AuthenticatedStorageImage)),
      const Size(240, 140),
    );

    gateway.result = _onePixelPng();
    await tester.tap(find.byTooltip('Riprova immagine'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(gateway.reads, hasLength(2));
  });

  testWidgets('check-in and canonical avatar adapters use their exact caps', (
    tester,
  ) async {
    final gateway = _ImageGateway()..result = _onePixelPng();
    await tester.pumpWidget(
      _app(
        gateway,
        const Column(
          children: [
            SizedBox(
              width: 120,
              height: 80,
              child: AuthenticatedCheckInPhoto(
                path: 'check_ins/alice/id/1.jpg',
                semanticLabel: 'Check-in',
              ),
            ),
            AuthenticatedAvatar(
              source: 'avatars/alice/version.jpg',
              radius: 24,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      gateway.reads,
      contains((
        path: 'check_ins/alice/id/1.jpg',
        maxBytes: checkInMediaMaxBytes,
      )),
    );
    expect(
      gateway.reads,
      contains((
        path: 'avatars/alice/version.jpg',
        maxBytes: avatarMediaMaxBytes,
      )),
    );
  });

  testWidgets('legacy URL remains isolated from authenticated Storage reads', (
    tester,
  ) async {
    final gateway = _ImageGateway();
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previousOnError);
    await tester.pumpWidget(
      _app(
        gateway,
        const AuthenticatedAvatar(
          source: 'https://legacy.example/avatar.jpg',
          radius: 24,
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect(gateway.reads, isEmpty);
  });

  test('v2 components never introduce public media loaders', () {
    for (final path in <String>[
      'lib/providers/media_provider.dart',
      'lib/widgets/authenticated_storage_image.dart',
      'lib/widgets/authenticated_check_in_photo.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('Image.network')), reason: path);
      expect(source, isNot(contains('CachedNetworkImage')), reason: path);
      expect(source, isNot(contains('getDownloadURL')), reason: path);
    }
    expect(File('lib/widgets/creamy_card.dart').existsSync(), isTrue);
  });
}

Widget _app(_ImageGateway gateway, Widget child) => ProviderScope(
  overrides: [
    storageServiceProvider.overrideWithValue(
      StorageService.forTesting(gateway),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

final class _ImageGateway implements StorageObjectGateway {
  final List<({String path, int maxBytes})> reads = [];
  Uint8List? result;
  Object? error;
  Completer<Uint8List?>? pending;

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    reads.add((path: path, maxBytes: maxBytes));
    if (error case final current?) throw current;
    if (pending case final current?) return current.future;
    return result;
  }

  @override
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata) =>
      throw UnimplementedError();
}

Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
