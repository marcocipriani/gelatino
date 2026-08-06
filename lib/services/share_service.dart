import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_strings.dart';

/// Captures the [ShareCheckInCard] mounted under [repaintKey] as a PNG and
/// hands it to `share_plus`, which covers both the native mobile share
/// sheet and the Web Share API (falling back to a download where the
/// browser doesn't support file sharing). No custom download path — nothing
/// asked for one yet.
Future<void> shareCheckInCard(
  GlobalKey repaintKey, {
  required String placeName,
}) async {
  final boundary =
      repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = (await image.toByteData(format: ImageByteFormat.png))!;
  final file = XFile.fromData(
    bytes.buffer.asUint8List(),
    mimeType: 'image/png',
    name: 'gelatino-check-in.png',
  );
  await SharePlus.instance.share(
    ShareParams(files: [file], text: AppStrings.shareCardMessage(placeName)),
  );
}
