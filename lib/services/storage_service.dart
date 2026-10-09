import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../firebase/firebase_providers.dart';

abstract interface class StorageObjectGateway {
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata);

  Future<Uint8List?> read(String path, int maxBytes);
}

/// Optional capability: gateways that can report how much of an upload has
/// been sent. Separate from [StorageObjectGateway] so test fakes stay small.
abstract interface class ProgressReportingStorageGateway {
  Future<String> putWithProgress(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
    void Function(double fraction) onProgress,
  );
}

final class FirebaseStorageObjectGateway
    implements StorageObjectGateway, ProgressReportingStorageGateway {
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
  Future<String> putWithProgress(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
    void Function(double fraction) onProgress,
  ) async {
    final task = _storage.ref().child(path).putData(bytes, metadata);
    final events = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    }, onError: (Object _) {});
    try {
      final snapshot = await task;
      return snapshot.ref.fullPath;
    } finally {
      await events.cancel();
    }
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) =>
      _storage.ref().child(path).getData(maxBytes);
}

/// Upload widths. The pickers request the same bound so the client never
/// decodes more pixels than it keeps.
const int checkInPhotoMaxWidth = 1024;
const int avatarMaxWidth = 512;

/// Bound for the picked photo before framing: room to zoom into a crop and
/// still cover [checkInPhotoMaxWidth].
const int checkInPickMaxWidth = 1600;

/// Custom metadata key on staging uploads; must match the Cloud Function.
const String stagingPhotoColorMetadataKey = 'dominant_color';

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

final class JpegUploadResult {
  const JpegUploadResult(this.bytes, this.averageColorHex);

  final Uint8List bytes;

  /// `#RRGGBB` average of the encoded pixels, used as a loading placeholder.
  final String averageColorHex;
}

/// Top-level so [compute] can run it in a background isolate. Returns null
/// when the bytes are not a decodable image.
///
/// The EXIF orientation is baked into the pixels and all EXIF is then dropped:
/// phone photos carry GPS coordinates and device details that must not reach
/// friends who can read the published photo.
@visibleForTesting
JpegUploadResult? encodeJpegForUpload(JpegUploadJob job) {
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
  return JpegUploadResult(
    Uint8List.fromList(img.encodeJpg(image, quality: job.quality)),
    _averageColorHex(image),
  );
}

String _averageColorHex(img.Image image) {
  final tiny = img.copyResize(
    image,
    width: 8,
    height: 8,
    interpolation: img.Interpolation.average,
  );
  var r = 0.0, g = 0.0, b = 0.0;
  for (final pixel in tiny) {
    r += pixel.rNormalized;
    g += pixel.gNormalized;
    b += pixel.bNormalized;
  }
  final count = tiny.width * tiny.height;
  String channel(double sum) => (sum / count * 255)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  return '#${channel(r)}${channel(g)}${channel(b)}'.toUpperCase();
}

/// A photo ready to frame: orientation baked in, no EXIF, known pixel size.
final class PreparedPhoto {
  const PreparedPhoto(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Crop in fractions of the prepared photo, so the UI never needs pixels.
final class PhotoCropJob {
  const PhotoCropJob(
    this.bytes, {
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final double left;
  final double top;
  final double width;
  final double height;
}

@visibleForTesting
PreparedPhoto? preparePhotoForCrop(Uint8List bytes) {
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (image == null) return null;
  final orientation = image.exif.imageIfd.orientation;
  if (orientation != null && orientation != 1) {
    image = img.bakeOrientation(image);
  }
  if (image.width > checkInPickMaxWidth) {
    image = img.copyResize(
      image,
      width: checkInPickMaxWidth,
      interpolation: img.Interpolation.average,
    );
  }
  image.exif = img.ExifData();
  return PreparedPhoto(
    Uint8List.fromList(img.encodeJpg(image, quality: 92)),
    image.width,
    image.height,
  );
}

@visibleForTesting
Uint8List? cropPhoto(PhotoCropJob job) {
  final image = img.decodeImage(job.bytes);
  if (image == null) return null;
  int px(double fraction, int size) =>
      (fraction * size).round().clamp(0, size - 1);
  final x = px(job.left, image.width);
  final y = px(job.top, image.height);
  final w = (job.width * image.width).round().clamp(1, image.width - x);
  final h = (job.height * image.height).round().clamp(1, image.height - y);
  final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}

final class StorageImageFailure implements Exception {
  const StorageImageFailure();

  @override
  String toString() => 'La foto selezionata non è un’immagine valida.';
}

class StorageService {
  StorageService(FirebaseStorage storage)
    : _gateway = FirebaseStorageObjectGateway(storage),
      _background = true;

  /// Processes images inline: a real isolate never completes under the fake
  /// clock of widget tests.
  StorageService.forTesting(this._gateway) : _background = false;

  /// Image work runs in an isolate via `compute`, which itself runs inline on
  /// web where isolates are unavailable.
  final bool _background;

  Future<R> _run<Q, R>(R Function(Q) job, Q input) =>
      _background ? compute(job, input) : Future<R>.sync(() => job(input));

  /// Decodes, orients and bounds a picked photo for the framing step. Null
  /// when the bytes are not an image.
  Future<PreparedPhoto?> preparePhoto(Uint8List bytes) =>
      _run(preparePhotoForCrop, bytes);

  /// Applies a framing chosen on [preparePhoto]'s output.
  Future<Uint8List?> crop(PhotoCropJob job) => _run(cropPhoto, job);

  final StorageObjectGateway _gateway;

  /// Resizes (never upscales) and re-encodes to JPEG off the UI thread.
  /// JPEG keeps photos small (tens of KB) instead of the multi-MB PNGs the old
  /// path produced, which is what was burning through the Storage quota.
  ///
  /// `compute` runs inline on web, where isolates are unavailable; there the
  /// picker already delivers an image at the target size, so the work is small.
  Future<JpegUploadResult> _compressToJpeg(
    Uint8List bytes, {
    required int maxWidth,
    required int quality,
  }) async {
    final encoded = await _run(
      encodeJpegForUpload,
      JpegUploadJob(bytes, maxWidth: maxWidth, quality: quality),
    );
    if (encoded == null) throw const StorageImageFailure();
    return encoded;
  }

  Future<String> uploadStagingPhoto({
    required Uint8List bytes,
    required String uid,
    required String checkInId,
    void Function(double fraction)? onProgress,
  }) async {
    _requireSegment(uid, 'uid');
    if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(checkInId)) {
      throw const FormatException('checkInId: invalid');
    }
    final jpeg = await _compressToJpeg(
      bytes,
      maxWidth: checkInPhotoMaxWidth,
      quality: 70,
    );
    final path = 'staging/$uid/$checkInId.jpg';
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'private, no-store',
      // Read by publishCheckIn and stored as the check-in's `photo_color`.
      customMetadata: <String, String>{
        stagingPhotoColorMetadataKey: jpeg.averageColorHex,
      },
    );
    if (_gateway case final ProgressReportingStorageGateway gateway
        when onProgress != null) {
      return gateway.putWithProgress(path, jpeg.bytes, metadata, onProgress);
    }
    return _gateway.put(path, jpeg.bytes, metadata);
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
    final jpegBytes = (await _compressToJpeg(
      bytes,
      maxWidth: avatarMaxWidth,
      quality: 75,
    )).bytes;
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
