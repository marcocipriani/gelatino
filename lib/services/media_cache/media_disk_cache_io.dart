import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'media_disk_cache.dart';

MediaDiskCache createPlatformMediaDiskCache() => FileMediaDiskCache(() async {
  final base = await getApplicationCacheDirectory();
  return Directory('${base.path}/authenticated_media');
});

/// Files named by the base64url of the Storage path, so distinct paths never
/// collide and no path segment reaches the filesystem unescaped.
final class FileMediaDiskCache implements MediaDiskCache {
  FileMediaDiskCache(
    this._resolveDirectory, {
    this.maxTotalBytes = _defaultMax,
  });

  static const int _defaultMax = 150 * 1024 * 1024;

  final Future<Directory> Function() _resolveDirectory;
  final int maxTotalBytes;
  Future<Directory?>? _directory;
  bool _trimmed = false;

  /// Resolved once; a platform without a cache directory disables the cache
  /// instead of failing every read.
  Future<Directory?> _dir() => _directory ??= () async {
    try {
      final dir = await _resolveDirectory();
      await dir.create(recursive: true);
      return dir;
    } catch (error) {
      debugPrint('Media disk cache disabled: $error');
      return null;
    }
  }();

  File _file(Directory dir, String path) =>
      File('${dir.path}/${base64Url.encode(utf8.encode(path))}');

  @override
  Future<Uint8List?> read(String path, {required int maxBytes}) async {
    if (!isImmutableMediaPath(path)) return null;
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final file = _file(dir, path);
      if (!await file.exists() || await file.length() > maxBytes) return null;
      return await file.readAsBytes();
    } catch (error) {
      debugPrint('Media disk cache read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    if (!isImmutableMediaPath(path)) return;
    try {
      final dir = await _dir();
      if (dir == null) return;
      // Write then rename, so a crash never leaves a truncated image behind.
      final target = _file(dir, path);
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
      if (!_trimmed) {
        _trimmed = true;
        await _trim(dir);
      }
    } catch (error) {
      debugPrint('Media disk cache write failed: $error');
    }
  }

  /// Once per session, drops the least recently written files past the cap.
  Future<void> _trim(Directory dir) async {
    final files = <(File, FileStat)>[];
    await for (final entity in dir.list()) {
      if (entity is File) files.add((entity, await entity.stat()));
    }
    var total = files.fold<int>(0, (sum, entry) => sum + entry.$2.size);
    if (total <= maxTotalBytes) return;
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final (file, stat) in files) {
      if (total <= maxTotalBytes) break;
      await file.delete();
      total -= stat.size;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (error) {
      debugPrint('Media disk cache clear failed: $error');
    }
  }
}
