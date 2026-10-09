import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../services/storage_service.dart';

/// Lets the author frame a picked photo at the feed card's aspect ratio.
///
/// Returns the cropped JPEG, or null when the author backs out. Bytes that
/// are not an image come back unchanged, so the upload reports them with its
/// usual error instead of this page failing silently.
Future<Uint8List?> framePhotoForCheckIn(
  BuildContext context,
  StorageService storage,
  Uint8List bytes,
) async {
  final prepared = await storage.preparePhoto(bytes);
  if (prepared == null) return bytes;
  if (!context.mounted) return null;
  final crop = await Navigator.of(context).push<PhotoCropJob>(
    MaterialPageRoute<PhotoCropJob>(
      fullscreenDialog: true,
      builder: (_) => PhotoCropPage(photo: prepared),
    ),
  );
  if (crop == null) return null;
  return storage.crop(crop);
}

final class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({super.key, required this.photo});

  final PreparedPhoto photo;

  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

final class _PhotoCropPageState extends State<PhotoCropPage> {
  final TransformationController _transform = TransformationController();
  Size? _frame;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// The photo scaled to cover the frame, before the author's pan and zoom.
  Size _coverSize(Size frame) {
    final photo = widget.photo;
    final scale = [
      frame.width / photo.width,
      frame.height / photo.height,
    ].reduce((a, b) => a > b ? a : b);
    return Size(photo.width * scale, photo.height * scale);
  }

  void _centerIn(Size frame) {
    if (_frame == frame) return;
    final firstLayout = _frame == null;
    _frame = frame;
    final cover = _coverSize(frame);
    void center() => _transform.value = Matrix4.translationValues(
      (frame.width - cover.width) / 2,
      (frame.height - cover.height) / 2,
      0,
    );
    // Before the viewer exists nobody listens yet; after that (a resize), the
    // viewer rebuilds on change, which is not allowed mid-layout.
    if (firstLayout) {
      center();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) center();
      });
    }
  }

  /// The visible frame as fractions of the photo: the viewer maps a child
  /// point p to `scale * p + translation`, so the frame's corners map back by
  /// inverting that and dividing by the covered size.
  PhotoCropJob _currentCrop() {
    final frame = _frame!;
    final cover = _coverSize(frame);
    final matrix = _transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    double fraction(double value) => value.clamp(0.0, 1.0);
    final left = fraction(-translation.x / (scale * cover.width));
    final top = fraction(-translation.y / (scale * cover.height));
    return PhotoCropJob(
      widget.photo.bytes,
      left: left,
      top: top,
      width: fraction(frame.width / (scale * cover.width)).clamp(0.0, 1 - left),
      height: fraction(
        frame.height / (scale * cover.height),
      ).clamp(0.0, 1 - top),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(AppStrings.checkInCropTitle),
      leading: IconButton(
        tooltip: AppStrings.cancel,
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.feed),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  label: AppStrings.checkInCropFrameSemantic,
                  image: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: AppLayout.checkInPhotoAspectRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final frame = constraints.biggest;
                          _centerIn(frame);
                          final cover = _coverSize(frame);
                          return InteractiveViewer(
                            key: const ValueKey<String>('photo-crop-viewer'),
                            transformationController: _transform,
                            constrained: false,
                            minScale: 1,
                            maxScale: 3,
                            child: SizedBox(
                              width: cover.width,
                              height: cover.height,
                              child: Image.memory(
                                widget.photo.bytes,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.checkInCropHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_currentCrop()),
                    child: const Text(AppStrings.checkInCropConfirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
