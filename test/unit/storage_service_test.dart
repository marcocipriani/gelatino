import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:gelatino/services/storage_service.dart';

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  test('bakes EXIF orientation into pixels and drops all EXIF', () {
    final source = img.Image(width: 4, height: 2)
      ..exif.imageIfd.orientation = 6
      ..exif.imageIfd['Make'] = img.IfdValueAscii('Phone');
    final encoded = encodeJpegForUpload(
      JpegUploadJob(img.encodeJpg(source), maxWidth: 1024, quality: 70),
    )!;

    final decoded = img.decodeJpg(encoded.bytes)!;
    expect((decoded.width, decoded.height), (2, 4));
    expect(decoded.exif.isEmpty, isTrue);
  });

  test('reports the average colour and tags the staging upload', () async {
    final red = img.Image(width: 16, height: 16)
      ..clear(img.ColorRgb8(200, 20, 40));
    final result = encodeJpegForUpload(
      JpegUploadJob(img.encodeJpg(red, quality: 100), maxWidth: 64, quality: 90),
    )!;
    final hex = int.parse(result.averageColorHex.substring(1), radix: 16);
    expect((hex >> 16) & 0xFF, closeTo(200, 6));
    expect((hex >> 8) & 0xFF, closeTo(20, 6));
    expect(hex & 0xFF, closeTo(40, 6));

    final gateway = _RecordingStorageGateway();
    await StorageService.forTesting(
      gateway,
    ).uploadStagingPhoto(bytes: png, uid: 'alice', checkInId: id);
    expect(
      gateway.puts.single.metadata.customMetadata?[stagingPhotoColorMetadataKey],
      matches(RegExp(r'^#[0-9A-F]{6}$')),
    );
  });

  test('staging upload reports progress through capable gateways', () async {
    final gateway = _ProgressGateway();
    final seen = <double>[];
    final path = await StorageService.forTesting(gateway).uploadStagingPhoto(
      bytes: png,
      uid: 'alice',
      checkInId: id,
      onProgress: seen.add,
    );

    expect(path, 'staging/alice/$id.jpg');
    expect(seen, [0.5, 1.0]);
  });

  test('downscales to the max width and never upscales', () {
    JpegUploadJob job(int width) => JpegUploadJob(
      img.encodeJpg(img.Image(width: width, height: width ~/ 2)),
      maxWidth: 100,
      quality: 70,
    );

    expect(img.decodeJpg(encodeJpegForUpload(job(400))!.bytes)!.width, 100);
    expect(img.decodeJpg(encodeJpegForUpload(job(60))!.bytes)!.width, 60);
  });

  test('uploads a real JPEG to the exact private staging path', () async {
    final gateway = _RecordingStorageGateway();
    final service = StorageService.forTesting(gateway);

    final path = await service.uploadStagingPhoto(
      bytes: png,
      uid: 'alice',
      checkInId: id,
    );

    expect(path, 'staging/alice/$id.jpg');
    expect(gateway.puts.single.path, path);
    expect(gateway.puts.single.bytes.take(2), [0xff, 0xd8]);
    expect(gateway.puts.single.metadata.contentType, 'image/jpeg');
    expect(gateway.puts.single.metadata.cacheControl, contains('private'));
  });

  test(
    'avatar uses the caller supplied stable version and private metadata',
    () async {
      final gateway = _RecordingStorageGateway();
      final service = StorageService.forTesting(gateway);

      final first = await service.uploadAvatar(
        bytes: png,
        uid: 'alice',
        version: 'version_1',
      );
      final retry = await service.uploadAvatar(
        bytes: png,
        uid: 'alice',
        version: 'version_1',
      );

      expect(first, 'avatars/alice/version_1.jpg');
      expect(retry, first);
      expect(gateway.puts.map((put) => put.path).toSet(), {first});
    },
  );

  test('undecodable bytes fail without uploading mislabeled data', () async {
    final gateway = _RecordingStorageGateway();

    await expectLater(
      StorageService.forTesting(gateway).uploadStagingPhoto(
        bytes: Uint8List.fromList([1, 2, 3]),
        uid: 'alice',
        checkInId: id,
      ),
      throwsA(isA<StorageImageFailure>()),
    );
    expect(gateway.puts, isEmpty);
  });

  test(
    'authenticated read returns bytes and only hides object-not-found',
    () async {
      final gateway = _RecordingStorageGateway()
        ..readResult = Uint8List.fromList([1, 2]);
      final service = StorageService.forTesting(gateway);

      expect(await service.readAuthenticatedObject('staging/alice/$id.jpg'), [
        1,
        2,
      ]);
      expect(gateway.reads.single.maxBytes, 5 * 1024 * 1024);

      gateway.readError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );
      expect(
        await service.readAuthenticatedObject('staging/alice/$id.jpg'),
        isNull,
      );

      gateway.readError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
      );
      await expectLater(
        service.readAuthenticatedObject('staging/alice/$id.jpg'),
        throwsA(isA<FirebaseException>()),
      );
    },
  );

  test('rejects hostile authenticated paths before reaching Storage', () async {
    final gateway = _RecordingStorageGateway();
    final service = StorageService.forTesting(gateway);
    final hostile = <String>[
      'staging/alice/../$id.jpg',
      'staging\\alice\\$id.jpg',
      'staging/alice/$id.jpg?token=x',
      'staging/alice/$id.jpg#fragment',
      'staging/al\u0000ice/$id.jpg',
      'staging//alice/$id.jpg',
    ];

    for (final path in hostile) {
      await expectLater(
        service.readAuthenticatedObject(path),
        throwsFormatException,
        reason: path,
      );
    }
    expect(gateway.reads, isEmpty);
  });

  test('rejects hostile upload owner segments', () async {
    final gateway = _RecordingStorageGateway();
    final service = StorageService.forTesting(gateway);

    for (final uid in ['..', r'alice\bob', 'alice?token', 'al\u0000ice']) {
      await expectLater(
        service.uploadStagingPhoto(bytes: png, uid: uid, checkInId: id),
        throwsFormatException,
        reason: uid,
      );
    }
    expect(gateway.puts, isEmpty);
  });
}

final class _RecordingStorageGateway implements StorageObjectGateway {
  final List<({String path, Uint8List bytes, SettableMetadata metadata})> puts =
      [];
  final List<({String path, int maxBytes})> reads = [];
  Uint8List? readResult;
  Object? readError;

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    puts.add((path: path, bytes: bytes, metadata: metadata));
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    reads.add((path: path, maxBytes: maxBytes));
    if (readError case final error?) throw error;
    return readResult;
  }
}

final class _ProgressGateway extends _RecordingStorageGateway
    implements ProgressReportingStorageGateway {
  @override
  Future<String> putWithProgress(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
    void Function(double fraction) onProgress,
  ) async {
    onProgress(0.5);
    onProgress(1.0);
    return put(path, bytes, metadata);
  }
}
