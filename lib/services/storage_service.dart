import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../firebase/firebase_providers.dart';

abstract interface class StorageObjectGateway {
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata);

  Future<Uint8List?> read(String path, int maxBytes);
}

final class FirebaseStorageObjectGateway implements StorageObjectGateway {
  const FirebaseStorageObjectGateway(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    final snapshot = await _storage.ref().child(path).putData(bytes, metadata);
    return snapshot.ref.fullPath;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) =>
      _storage.ref().child(path).getData(maxBytes);
}

/// Upload widths. The pickers request the same bound so the client never
/// decodes more pixels than it keeps.
const int checkInPhotoMaxWidth = 1024;
const int avatarMaxWidth = 512;

final class JpegUploadJob {
  const JpegUploadJob(
    this.bytes, {
    required this.maxWidth,
    required this.quality,
  });

  final Uint8List bytes;
  final int maxWidth;
  final int quality;
}

/// Top-level so [compute] can run it in a background isolate. Returns null
/// when the bytes are not a decodable image.
///
/// The EXIF orientation is baked into the pixels and all EXIF is then dropped:
/// phone photos carry GPS coordinates and device details that must not reach
/// friends who can read the published photo.
@visibleForTesting
Uint8List? encodeJpegForUpload(JpegUploadJob job) {
  img.Image? image;
  try {
    image = img.decodeImage(job.bytes);
  } catch (_) {
    return null;
  }
  if (image == null) return null;
  final orientation = image.exif.imageIfd.orientation;
  if (orientation != null && orientation != 1) {
    image = img.bakeOrientation(image);
  }
  if (image.width > job.maxWidth) {
    image = img.copyResize(
      image,
      width: job.maxWidth,
      interpolation: img.Interpolation.average,
    );
  }
  image.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(image, quality: job.quality));
}

Future<Uint8List?> _encodeInBackground(JpegUploadJob job) =>
    compute(encodeJpegForUpload, job);

Future<Uint8List?> _encodeInline(JpegUploadJob job) async =>
    encodeJpegForUpload(job);

final class StorageImageFailure implements Exception {
  const StorageImageFailure();

  @override
  String toString() => 'La foto selezionata non è un’immagine valida.';
}

class StorageService {
  StorageService(FirebaseStorage storage)
    : _gateway = FirebaseStorageObjectGateway(storage),
      _encodeJpeg = _encodeInBackground;

  /// Encodes inline: a real isolate never completes under the fake clock of
  /// widget tests.
  StorageService.forTesting(this._gateway) : _encodeJpeg = _encodeInline;

  final StorageObjectGateway _gateway;
  final Future<Uint8List?> Function(JpegUploadJob job) _encodeJpeg;

  /// Resizes (never upscales) and re-encodes to JPEG off the UI thread.
  /// JPEG keeps photos small (tens of KB) instead of the multi-MB PNGs the old
  /// path produced, which is what was burning through the Storage quota.
  ///
  /// `compute` runs inline on web, where isolates are unavailable; there the
  /// picker already delivers an image at the target size, so the work is small.
  Future<Uint8List> _compressToJpeg(
    Uint8List bytes, {
    required int maxWidth,
    required int quality,
  }) async {
    final encoded = await _encodeJpeg(
      JpegUploadJob(bytes, maxWidth: maxWidth, quality: quality),
    );
    if (encoded == null) throw const StorageImageFailure();
    return encoded;
  }

  Future<String> uploadStagingPhoto({
    required Uint8List bytes,
    required String uid,
    required String checkInId,
  }) async {
    _requireSegment(uid, 'uid');
    if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(checkInId)) {
      throw const FormatException('checkInId: invalid');
    }
    final jpegBytes = await _compressToJpeg(
      bytes,
      maxWidth: checkInPhotoMaxWidth,
      quality: 70,
    );
    final path = 'staging/$uid/$checkInId.jpg';
    return _gateway.put(
      path,
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'private, no-store',
      ),
    );
  }

  Future<Uint8List?> readAuthenticatedObject(
    String path, {
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    if (!_isSafeStoragePath(path)) {
      throw const FormatException('path: invalid authenticated object path');
    }
    if (maxBytes <= 0) throw const FormatException('maxBytes: invalid');
    try {
      return await _gateway.read(path, maxBytes);
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String uid,
    required String version,
  }) async {
    _requireSegment(uid, 'uid');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(version)) {
      throw const FormatException('version: invalid');
    }
    final jpegBytes = await _compressToJpeg(
      bytes,
      maxWidth: avatarMaxWidth,
      quality: 75,
    );
    final path = 'avatars/$uid/$version.jpg';
    return _gateway.put(
      path,
      jpegBytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'private, max-age=31536000, immutable',
      ),
    );
  }
}

void _requireSegment(String value, String label) {
  if (!_isSafeStorageSegment(value)) {
    throw FormatException('$label: invalid');
  }
}

bool _isSafeStoragePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.length > 1024) return false;
  final segments = path.split('/');
  return segments.isNotEmpty && segments.every(_isSafeStorageSegment);
}

bool _isSafeStorageSegment(String value) {
  if (value.isEmpty || value.length > 128 || value == '.' || value == '..') {
    return false;
  }
  for (final unit in value.codeUnits) {
    if (unit <= 0x1f ||
        unit == 0x7f ||
        unit == 0x2f ||
        unit == 0x5c ||
        unit == 0x3f ||
        unit == 0x23) {
      return false;
    }
  }
  return true;
}

final storageServiceProvider = Provider(
  (ref) => StorageService(ref.watch(firebaseStorageProvider)),
);
