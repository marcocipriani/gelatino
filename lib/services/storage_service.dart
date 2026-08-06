import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
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

final class StorageImageFailure implements Exception {
  const StorageImageFailure();

  @override
  String toString() => 'La foto selezionata non è un’immagine valida.';
}

class StorageService {
  StorageService(FirebaseStorage storage)
    : _gateway = FirebaseStorageObjectGateway(storage);

  StorageService.forTesting(this._gateway);

  final StorageObjectGateway _gateway;

  /// Resizes (never upscales) and re-encodes to JPEG. JPEG keeps photos small
  /// (tens of KB) instead of the multi-MB PNGs the old path produced, which is
  /// what was burning through the Storage quota.
  Uint8List _compressToJpeg(
    Uint8List bytes, {
    int maxWidth = 1024,
    int quality = 70,
  }) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const StorageImageFailure();
    }
    if (decoded == null) throw const StorageImageFailure();
    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
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
    final jpegBytes = _compressToJpeg(bytes, maxWidth: 1024, quality: 70);
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
    final jpegBytes = _compressToJpeg(bytes, maxWidth: 512, quality: 75);
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
