@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/services/media_cache/media_disk_cache_web.dart';

// Run with: flutter test --platform chrome test/web
void main() {
  test('round-trips immutable paths, respects maxBytes and clears', () async {
    final cache = WebCacheStorageMediaCache();
    await cache.clear();
    const path = 'check_ins/alice/ABCDEFGHIJKLMNOPQRST/1.jpg';
    await cache.write(path, Uint8List.fromList([1, 2, 3]));

    expect(await cache.read(path, maxBytes: 10), [1, 2, 3]);
    expect(await cache.read(path, maxBytes: 2), isNull);
    expect(
      await WebCacheStorageMediaCache().read(path, maxBytes: 10),
      [1, 2, 3],
    );

    await cache.clear();
    expect(await cache.read(path, maxBytes: 10), isNull);
  });

  test('never caches staging and trims past the entry cap', () async {
    final cache = WebCacheStorageMediaCache(maxEntries: 1);
    await cache.clear();
    await cache.write('staging/alice/x.jpg', Uint8List.fromList([1]));
    expect(await cache.read('staging/alice/x.jpg', maxBytes: 10), isNull);

    await cache.write('avatars/alice/v1.jpg', Uint8List.fromList([1]));
    await cache.write('avatars/alice/v2.jpg', Uint8List.fromList([2]));
    // Trim runs once, on the first write of the session.
    final fresh = WebCacheStorageMediaCache(maxEntries: 1);
    await fresh.write('avatars/alice/v3.jpg', Uint8List.fromList([3]));

    expect(await fresh.read('avatars/alice/v1.jpg', maxBytes: 10), isNull);
    expect(await fresh.read('avatars/alice/v3.jpg', maxBytes: 10), [3]);
    await fresh.clear();
  });
}
