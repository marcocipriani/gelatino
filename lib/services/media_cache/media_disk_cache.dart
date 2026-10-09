import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists authenticated Storage objects across app launches so a cold start
/// does not re-download the whole feed.
///
/// Only immutable objects are cached: published check-in photos and avatars
/// embed a version in their path, so a path never changes content. Staging
/// uploads are overwritten in place and always go to the network.
///
/// Every failure degrades to a cache miss; the cache must never break a read.
abstract interface class MediaDiskCache {
  Future<Uint8List?> read(String path, {required int maxBytes});

  Future<void> write(String path, Uint8List bytes);

  /// Called on sign-out so the next account on this device starts empty.
  Future<void> clear();
}

bool isImmutableMediaPath(String path) =>
    path.startsWith('check_ins/') || path.startsWith('avatars/');

/// No-op cache: the default, so tests never touch the filesystem. Also what
/// web gets, where the browser HTTP cache honours the objects' `immutable`
/// Cache-Control.
final class NoMediaDiskCache implements MediaDiskCache {
  const NoMediaDiskCache();

  @override
  Future<Uint8List?> read(String path, {required int maxBytes}) async => null;

  @override
  Future<void> write(String path, Uint8List bytes) async {}

  @override
  Future<void> clear() async {}
}

/// `main.dart` overrides this with `createPlatformMediaDiskCache()`.
final mediaDiskCacheProvider = Provider<MediaDiskCache>(
  (ref) => const NoMediaDiskCache(),
);
