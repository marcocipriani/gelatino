import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../constants/app_strings.dart';

/// A deterministic local illustration used where Collection needs a cover.
class PlaceEditorialCover extends StatelessWidget {
  const PlaceEditorialCover({
    required this.placeId,
    required this.placeName,
    this.borderRadius = AppRadii.card,
    super.key,
  });

  final String placeId;
  final String placeName;
  final double borderRadius;

  static const int paletteCount = 4;

  static int paletteIndexFor(String placeId) =>
      placeId.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % paletteCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppStrings.placeCoverSemantic(placeName),
      child: ClipRRect(
        key: ValueKey<String>('place-editorial-cover-$placeId'),
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          painter: _EditorialCoverPainter(
            palette: _palettes[paletteIndexFor(placeId)],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

const List<_CoverPalette> _palettes = <_CoverPalette>[
  _CoverPalette(Color(0xFFFFD8E1), Color(0xFFFF4D6D), Color(0xFFFFEA00)),
  _CoverPalette(Color(0xFFC9FFF3), Color(0xFF00A887), Color(0xFFFFF4C2)),
  _CoverPalette(Color(0xFFD5F3FF), Color(0xFF00BFFF), Color(0xFFFFD2A8)),
  _CoverPalette(Color(0xFFE9DCFF), Color(0xFF7950C7), Color(0xFFFFC9D4)),
];

final class _CoverPalette {
  const _CoverPalette(this.background, this.accent, this.highlight);

  final Color background;
  final Color accent;
  final Color highlight;
}

final class _EditorialCoverPainter extends CustomPainter {
  const _EditorialCoverPainter({required this.palette});

  final _CoverPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);

    final accent = Paint()..color = palette.accent;
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.25),
      size.shortestSide * 0.26,
      accent,
    );

    final highlight = Paint()..color = palette.highlight;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.28, size.height * 0.64),
        width: size.width * 0.48,
        height: size.height * 0.58,
      ),
      highlight,
    );

    final line = Paint()
      ..color = palette.accent.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.12,
        size.width * 0.5,
        size.height * 0.62,
      ),
      -0.55,
      2.3,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _EditorialCoverPainter oldDelegate) =>
      oldDelegate.palette != palette;
}
