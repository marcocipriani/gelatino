import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../e2e/e2e_config.dart';
import '../../e2e/emulator_photo_fixture.dart';
import '../../constants/app_strings.dart';

final class PhotoStep extends StatelessWidget {
  const PhotoStep({
    required this.bytes,
    required this.hasStagedPhoto,
    required this.isUploading,
    this.uploadProgress,
    required this.photoMissing,
    required this.uploadFailed,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onRetry,
    required this.onRetryUpload,
    this.onE2EPhoto,
    super.key,
  });

  final Uint8List? bytes;
  final bool hasStagedPhoto;
  final bool isUploading;
  final double? uploadProgress;
  final bool photoMissing;
  final bool uploadFailed;
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onRemove;
  final VoidCallback onRetry;
  final VoidCallback onRetryUpload;
  final VoidCallback? onE2EPhoto;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('check-in-page-0'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Semantics(
        label: hasStagedPhoto
            ? AppStrings.checkInPhotoPreview
            : AppStrings.checkInNoPhotoChosen,
        image: true,
        child: Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: bytes == null
              ? const Center(child: Icon(Icons.add_a_photo_outlined, size: 64))
              : Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.image_outlined, size: 64)),
                ),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          if (uploadFailed)
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onRetryUpload,
                child: const Text(AppStrings.checkInRetryUpload),
              ),
            ),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text(AppStrings.checkInCamera),
            ),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text(AppStrings.checkInGallery),
            ),
          ),
          if (e2eControlsEnabled)
            EmulatorPhotoFixtureButton(onPressed: onE2EPhoto),
          if (hasStagedPhoto || bytes != null)
            SizedBox(
              height: 48,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text(AppStrings.remove),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (isUploading && uploadProgress != null)
        _UploadProgress(fraction: uploadProgress!)
      else if (isUploading)
        const Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text(AppStrings.checkInCompressing)),
          ],
        )
      else if (uploadFailed)
        const Text(AppStrings.checkInUploadInterrupted)
      else if (photoMissing)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: <Widget>[
            const Text(AppStrings.checkInPrivatePhotoNotFound),
            TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
          ],
        )
      else if (hasStagedPhoto)
        const Row(
          children: <Widget>[
            Icon(Icons.lock_outline, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(AppStrings.checkInPrivatePhotoUploaded)),
          ],
        ),
    ],
  );
}

final class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final percent = (fraction.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const ValueKey<String>('check-in-upload-progress'),
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(AppStrings.checkInUploadingPercent(percent)),
      ],
    );
  }
}
