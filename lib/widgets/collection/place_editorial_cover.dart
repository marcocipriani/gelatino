import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../../constants/app_strings.dart';
import '../melt_pin.dart';

/// A deterministic local illustration used where Collection needs a cover:
/// the Melt Pin, cropped large, on one deep flavour.
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
    final palette = _palettes[paletteIndexFor(placeId)];
    final cover = Semantics(
      image: true,
      label: AppStrings.placeCoverSemantic(placeName),
      child: ClipRRect(
        key: ValueKey<String>('place-editorial-cover-$placeId'),
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: palette.ground,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                children: [
                  // Tone on tone, bleeding off the edge.
                  Positioned(
                    right: -width * 0.1,
                    top: -height * 0.22,
                    child: MeltPinGlyph(color: palette.tone, height: height * 1.7),
                  ),
                  Positioned(
                    left: width * 0.1,
                    top: height * 0.2,
                    child: MeltPinGlyph(
                      color: palette.mark,
                      swirl: palette.ground,
                      height: height * 0.62,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (AppMotion.reduced(context)) return cover;
    // The cover carries you from the Collection card into the place.
    return Hero(tag: 'place-cover-$placeId', child: cover);
  }
}

const List<_CoverPalette> _palettes = <_CoverPalette>[
  // Fragola
  _CoverPalette(Color(0xFF7A0F2E), Color(0xFF981A3E), AppColors.fragola),
  // Menta
  _CoverPalette(Color(0xFF0B4A3F), Color(0xFF125C4F), AppColors.menta),
  // Puffo
  _CoverPalette(Color(0xFF0B3A52), Color(0xFF124A66), AppColors.puffo),
  // Cacao e panna
  _CoverPalette(Color(0xFF3A2520), Color(0xFF4B322B), AppColors.fiorDiPanna),
];

final class _CoverPalette {
  const _CoverPalette(this.ground, this.tone, this.mark);

  final Color ground;
  final Color tone;
  final Color mark;
}
