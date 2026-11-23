import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../constants/app_strings.dart';

/// The Melt Pin mark in any colour. The swirl is negative space, so it shows
/// what is behind it unless [swirl] backs it with a solid colour — as it must
/// on a map, where tiles would shred the shape.
class MeltPinGlyph extends StatelessWidget {
  const MeltPinGlyph({
    required this.color,
    required this.height,
    this.swirl,
    this.artKey,
    super.key,
  });

  static const aspectRatio = 320 / 448;

  final Color color;
  final double height;
  final Color? swirl;
  final Key? artKey;

  @override
  Widget build(BuildContext context) {
    final width = height * aspectRatio;
    final unit = height / 448;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          if (swirl != null)
            Positioned(
              // Circle (160,167) r125 in artwork units: covers the swirl and
              // never pokes out of the silhouette.
              left: 35 * unit,
              top: 42 * unit,
              width: 250 * unit,
              height: 250 * unit,
              child: DecoratedBox(
                decoration: BoxDecoration(color: swirl, shape: BoxShape.circle),
              ),
            ),
          SvgPicture.asset(
            'assets/images/pin-fondente.svg',
            key: artKey,
            width: width,
            height: height,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}

class MeltPin extends StatelessWidget {
  const MeltPin({required this.onPressed, this.compact = false, super.key});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : 48.0;
    return Semantics(
      key: const ValueKey('melt-pin'),
      button: true,
      label: AppStrings.checkInTitle,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: AppFocusRing(
          borderRadius: AppRadii.pill,
          child: SizedBox.square(
            dimension: size,
            child: IconButton.filled(
              tooltip: AppStrings.checkInTitle,
              onPressed: onPressed,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.fragola,
                foregroundColor: AppColors.fondente,
                minimumSize: const Size.square(AppLayout.touchTarget),
                shape: const CircleBorder(),
              ),
              icon: MeltPinGlyph(
                color: AppColors.fondente,
                height: compact ? 32 : 27,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
