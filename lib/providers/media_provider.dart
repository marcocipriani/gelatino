import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_cache/media_disk_cache.dart';
import '../services/storage_service.dart';

const int checkInMediaMaxBytes = 5 * 1024 * 1024;
const int avatarMediaMaxBytes = 2 * 1024 * 1024;

/// Identifies one authenticated Storage read without collapsing versions or
/// consumers that enforce different payload limits.
final class AuthenticatedMediaKey {
  const AuthenticatedMediaKey(this.path, this.maxBytes);

  final String path;
  final int maxBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticatedMediaKey &&
          other.path == path &&
          other.maxBytes == maxBytes;

  @override
  int get hashCode => Object.hash(path, maxBytes);

  @override
  String toString() => 'AuthenticatedMediaKey($path, $maxBytes)';
}

/// Successful bytes are cached for this exact key for the session. Not
/// `autoDispose`: a feed card scrolling out of view used to drop its bytes and
/// re-download the whole object on the way back. Photos are capped at 1024px /
/// quality 70 upstream, so a long feed holds single-digit megabytes.
///
/// Immutable objects are also persisted by [MediaDiskCache], so they survive
/// app restarts without another Storage download (and its rules lookups).
///
/// Two retries with backoff cover transient network failures; past that the
/// keyed provider is invalidated by the manual retry affordance in
/// `AuthenticatedStorageImage`.
final mediaBytesProvider =
    FutureProvider.family<Uint8List?, AuthenticatedMediaKey>(
      (ref, key) async {
        final cache = ref.watch(mediaDiskCacheProvider);
        final cached = await cache.read(key.path, maxBytes: key.maxBytes);
        if (cached != null) return cached;
        final bytes = await ref
            .watch(storageServiceProvider)
            .readAuthenticatedObject(key.path, maxBytes: key.maxBytes);
        if (bytes != null) unawaited(cache.write(key.path, bytes));
        return bytes;
      },
      retry: (retryCount, error) =>
          retryCount < 2 ? Duration(seconds: 1 << retryCount) : null,
    );
