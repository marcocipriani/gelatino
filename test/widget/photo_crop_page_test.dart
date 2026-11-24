import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/screens/check_in/photo_crop_page.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:image/image.dart' as img;

void main() {
  Future<PhotoCropJob?> frame(
    WidgetTester tester,
    PreparedPhoto photo, {
    Offset drag = Offset.zero,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PhotoCropJob? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<PhotoCropJob>(
                MaterialPageRoute<PhotoCropJob>(
                  builder: (_) => PhotoCropPage(photo: photo),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (drag != Offset.zero) {
      await tester.drag(
        find.byKey(const ValueKey<String>('photo-crop-viewer')),
        drag,
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Usa questa inquadratura'));
    await tester.pumpAndSettle();
    return result;
  }

  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 1, height: 1)),
  );

  testWidgets('default framing is the centred band of a portrait photo', (
    tester,
  ) async {
    final crop = (await frame(tester, PreparedPhoto(bytes, 900, 1600)))!;

    final height = (900 * 9 / 16) / 1600;
    expect(crop.left, closeTo(0, 1e-6));
    expect(crop.width, closeTo(1, 1e-6));
    expect(crop.height, closeTo(height, 1e-3));
    expect(crop.top, closeTo((1 - height) / 2, 1e-3));
  });

  testWidgets('dragging the photo up moves the framing down, within bounds', (
    tester,
  ) async {
    final centred = (await frame(tester, PreparedPhoto(bytes, 900, 1600)))!;
    final moved = (await frame(
      tester,
      PreparedPhoto(bytes, 900, 1600),
      drag: const Offset(0, -5000),
    ))!;

    expect(moved.top, greaterThan(centred.top));
    expect(moved.top + moved.height, closeTo(1, 1e-3));
  });

  testWidgets('backing out returns no framing', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PhotoCropJob? result = PhotoCropJob(
      bytes,
      left: 0,
      top: 0,
      width: 1,
      height: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<PhotoCropJob>(
                MaterialPageRoute<PhotoCropJob>(
                  builder: (_) =>
                      PhotoCropPage(photo: PreparedPhoto(bytes, 10, 10)),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Annulla'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  test('prepare bakes orientation, bounds width and drops EXIF', () {
    final source = img.Image(width: 2000, height: 1000)
      ..exif.imageIfd.orientation = 6;
    final prepared = preparePhotoForCrop(img.encodeJpg(source))!;

    // Rotated to 1000x2000, already under the 1600 bound.
    expect((prepared.width, prepared.height), (1000, 2000));
    expect(img.decodeJpg(prepared.bytes)!.exif.isEmpty, isTrue);
    expect(preparePhotoForCrop(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('crop maps fractions to pixels and stays inside the image', () {
    final source = img.encodeJpg(img.Image(width: 160, height: 90));
    final half = img.decodeJpg(
      cropPhoto(
        PhotoCropJob(source, left: 0.5, top: 0, width: 0.5, height: 1),
      )!,
    )!;
    expect((half.width, half.height), (80, 90));

    final overflow = img.decodeJpg(
      cropPhoto(
        PhotoCropJob(source, left: 0.9, top: 0.9, width: 1, height: 1),
      )!,
    )!;
    expect(overflow.width, lessThanOrEqualTo(16));
    expect(overflow.height, lessThanOrEqualTo(9));
  });
}
