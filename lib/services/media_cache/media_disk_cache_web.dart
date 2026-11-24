import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'media_disk_cache.dart';

MediaDiskCache createPlatformMediaDiskCache() => WebCacheStorageMediaCache();

/// Browser counterpart of the file cache, on the Cache Storage API.
///
/// `getData()` sends an Authorization header, so whether the HTTP cache reuses
/// the response is up to the browser; this makes reuse explicit. Entries are
/// keyed by a same-origin URL that is never fetched, only used as a key.
final class WebCacheStorageMediaCache implements MediaDiskCache {
  WebCacheStorageMediaCache({this.maxEntries = 400});

  static const String _cacheName = 'gelatino-media-v1';

  /// Cache Storage has no per-entry size, so the bound is a count: at ~100 KB
  /// a photo, 400 entries stay around 40 MB.
  final int maxEntries;
  Future<web.Cache?>? _cache;
  bool _trimmed = false;

  Future<web.Cache?> _open() => _cache ??= () async {
    try {
      return await web.window.caches.open(_cacheName).toDart;
    } catch (error) {
      // Insecure contexts and some private modes expose no Cache Storage.
      debugPrint('Media web cache disabled: $error');
      return null;
    }
  }();

  JSString _key(String path) =>
      '${web.window.location.origin}/__media/${Uri.encodeComponent(path)}'.toJS;

  @override
  Future<Uint8List?> read(String path, {required int maxBytes}) async {
    if (!isImmutableMediaPath(path)) return null;
    try {
      final cache = await _open();
      if (cache == null) return null;
      final response = await cache.match(_key(path)).toDart;
      if (response == null) return null;
      final bytes = (await response.arrayBuffer().toDart).toDart.asUint8List();
      return bytes.length > maxBytes ? null : bytes;
    } catch (error) {
      debugPrint('Media web cache read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    if (!isImmutableMediaPath(path)) return;
    try {
      final cache = await _open();
      if (cache == null) return;
      await cache
          .put(
            _key(path),
            // Read back as raw bytes, so no content type is needed.
            web.Response(bytes.toJS),
          )
          .toDart;
      if (!_trimmed) {
        _trimmed = true;
        await _trim(cache);
      }
    } catch (error) {
      debugPrint('Media web cache write failed: $error');
    }
  }

  /// Once per session, drops the oldest entries (keys come back in insertion
  /// order) past [maxEntries].
  Future<void> _trim(web.Cache cache) async {
    final keys = (await cache.keys().toDart).toDart;
    final excess = keys.length - maxEntries;
    for (var index = 0; index < excess; index++) {
      await cache.delete(keys[index]).toDart;
    }
  }

  @override
  Future<void> clear() async {
    try {
      _cache = null;
      await web.window.caches.delete(_cacheName).toDart;
    } catch (error) {
      debugPrint('Media web cache clear failed: $error');
    }
  }
}
