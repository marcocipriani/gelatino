import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../providers/media_provider.dart';
import '../services/media_telemetry.dart';
import 'skeleton_loader.dart';
import '../constants/app_strings.dart';

final class AuthenticatedStorageImage extends ConsumerWidget {
  const AuthenticatedStorageImage({
    super.key,
    required this.path,
    required this.maxBytes,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.missingIcon = Icons.image_not_supported_outlined,
    this.placeholderColor,
  });

  final String path;
  final int maxBytes;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final IconData missingIcon;

  /// Shown flat while loading instead of the shimmering skeleton, so the card
  /// already has the photo's tone before its bytes arrive.
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = AuthenticatedMediaKey(path, maxBytes);
    final bytes = ref.watch(mediaBytesProvider(key));
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _MediaGeometry.resolve(
            constraints,
            width: width,
            height: height,
          );
          void retry() => ref.invalidate(mediaBytesProvider(key));
          return SizedBox(
            width: geometry.width,
            height: geometry.height,
            child: Semantics(
              image: true,
              label: semanticLabel,
              child: bytes.when(
                skipLoadingOnRefresh: false,
                data: (value) => value == null
                    ? _MediaFallback(icon: missingIcon, onRetry: retry)
                    : _MemoryStorageImage(
                        onDecodeError: (error) => ref
                            .read(mediaTelemetryProvider)
                            .report(MediaFailureKind.decode, error),
                        bytes: value,
                        width: geometry.width,
                        height: geometry.height,
                        fit: fit,
                        alignment: alignment,
                        missingIcon: missingIcon,
                        onRetry: retry,
                      ),
                loading: () => placeholderColor == null
                    ? SkeletonBox(
                        width: geometry.width,
                        height: geometry.height,
                        borderRadius: BorderRadius.zero,
                      )
                    : ColoredBox(
                        key: const ValueKey<String>('media-color-placeholder'),
                        color: placeholderColor!,
                        child: SizedBox(
                          width: geometry.width,
                          height: geometry.height,
                        ),
                      ),
                error: (error, stackTrace) {
                  debugPrint('Authenticated Storage image failed: $error');
                  return _MediaFallback(icon: missingIcon, onRetry: retry);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _MediaGeometry {
  const _MediaGeometry(this.width, this.height);

  final double width;
  final double height;

  static _MediaGeometry resolve(
    BoxConstraints constraints, {
    required double? width,
    required double? height,
  }) {
    double? resolvedWidth = width;
    double? resolvedHeight = height;
    if (resolvedWidth == null && constraints.hasBoundedWidth) {
      resolvedWidth = constraints.maxWidth;
    }
    if (resolvedHeight == null && constraints.hasBoundedHeight) {
      resolvedHeight = constraints.maxHeight;
    }
    resolvedWidth ??= resolvedHeight;
    resolvedHeight ??= resolvedWidth;
    return _MediaGeometry(
      resolvedWidth ?? AppLayout.touchTarget,
      resolvedHeight ?? AppLayout.touchTarget,
    );
  }
}

final class _MemoryStorageImage extends StatelessWidget {
  const _MemoryStorageImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.fit,
    required this.alignment,
    required this.missingIcon,
    required this.onRetry,
    required this.onDecodeError,
  });

  final void Function(Object error) onDecodeError;
  final Uint8List bytes;
  final double width;
  final double height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final IconData missingIcon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    gaplessPlayback: true,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stackTrace) {
      debugPrint('Authenticated Storage image decode failed: $error');
      onDecodeError(error);
      return _MediaFallback(icon: missingIcon, onRetry: onRetry);
    },
  );
}

final class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.icon, required this.onRetry});

  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      constraints: const BoxConstraints(
        minWidth: AppLayout.touchTarget,
        minHeight: AppLayout.touchTarget,
      ),
      tooltip: AppStrings.retryImageTooltip,
      onPressed: onRetry,
      icon: Icon(icon),
    ),
  );
}
