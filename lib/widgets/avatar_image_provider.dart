import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/media_provider.dart';
import '../services/media_telemetry.dart';

ImageProvider<Object>? avatarImageProvider(String? source) {
  if (source == null || source.isEmpty) return null;
  final uri = Uri.tryParse(source);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return NetworkImage(source);
}

bool isCanonicalAvatarPath(String? source) {
  if (source == null) return false;
  final segments = source.split('/');
  if (segments.length != 3 || segments.first != 'avatars') return false;
  return _safeAvatarSegment(segments[1]) &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}\.jpg$').hasMatch(segments[2]);
}

bool _safeAvatarSegment(String value) {
  if (value.isEmpty || value.length > 128 || value == '.' || value == '..') {
    return false;
  }
  return value.codeUnits.every(
    (unit) =>
        unit > 0x1f &&
        unit != 0x7f &&
        unit != 0x2f &&
        unit != 0x5c &&
        unit != 0x3f &&
        unit != 0x23,
  );
}

final class AuthenticatedAvatar extends ConsumerWidget {
  const AuthenticatedAvatar({
    super.key,
    this.source,
    this.bytes,
    this.radius = 20,
    this.iconSize,
    this.iconColor,
    this.icon = Icons.person,
    this.backgroundColor,
  });

  final String? source;
  final Uint8List? bytes;
  final double radius;
  final double? iconSize;
  final Color? iconColor;
  final IconData icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avatars are stored at 512px but drawn at 32–96dp: decoding at display
    // size keeps a list of them from holding full bitmaps in memory. The
    // margin covers non-square sources, which `cover` scales by the short side.
    final decodeWidth =
        (radius * 2 * MediaQuery.devicePixelRatioOf(context) * 1.5).ceil();
    Widget avatar(ImageProvider<Object>? image) => _avatar(
      image == null
          ? null
          : ResizeImage.resizeIfNeeded(decodeWidth, null, image),
      onError: (error, _) => ref
          .read(mediaTelemetryProvider)
          .report(MediaFailureKind.decode, error),
    );
    final selectedBytes = bytes;
    if (selectedBytes != null) {
      return avatar(MemoryImage(selectedBytes));
    }
    final legacyImage = avatarImageProvider(source);
    if (legacyImage != null) return avatar(legacyImage);
    final path = source;
    if (!isCanonicalAvatarPath(path)) return avatar(null);
    final mediaKey = AuthenticatedMediaKey(path!, avatarMediaMaxBytes);
    return ref
        .watch(mediaBytesProvider(mediaKey))
        .when(
          data: (authenticatedBytes) => avatar(
            authenticatedBytes == null ? null : MemoryImage(authenticatedBytes),
          ),
          loading: () => avatar(null),
          error: (error, stackTrace) {
            debugPrint('Authenticated avatar failed: $error');
            return avatar(null);
          },
        );
  }

  Widget _avatar(
    ImageProvider<Object>? image, {
    ImageErrorListener? onError,
  }) => CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor,
    backgroundImage: image,
    onBackgroundImageError: image == null ? null : onError,
    child: image == null
        ? Icon(icon, size: iconSize ?? radius, color: iconColor)
        : null,
  );
}
