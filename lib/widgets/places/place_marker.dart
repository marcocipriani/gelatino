import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design/app_tokens.dart';
import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';

/// Melt Pin marker. The five `pin-*.svg` brand assets share one path and differ
/// only by `fill`, so a single asset plus a `ColorFilter` renders all of them —
/// and lets the default variant pick its colour instead of baking one in.
final class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    required this.entry,
    required this.variant,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  /// Melt Pin artwork is 320x448; the box keeps that ratio so the tip lands on
  /// the geographic point. Width still clears the 44dp touch target.
  static const double pinWidth = AppLayout.touchTarget;
  static const double pinHeight = 58;
  static const double selectedScale = 1.25;

  /// The box is sized for the *selected* pin so the hit area does not move as
  /// selection changes, and the enlarged pin is not clipped by the marker layer.
  static const double boxWidth = pinWidth * selectedScale;
  static const double boxHeight = pinHeight * selectedScale;

  final DiscoveryPlace entry;
  final PlaceMarkerVariant variant;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Map tiles stay light in both themes, so marker colours are fixed brand
    // tokens rather than scheme colours that would wash out in dark mode.
    final (color, stateLabel) = switch (variant) {
      PlaceMarkerVariant.favorite => (
        AppColors.sorbetto,
        AppStrings.placeMarkerFavorite,
      ),
      PlaceMarkerVariant.saved => (
        AppColors.menta,
        AppStrings.placeMarkerSaved,
      ),
      PlaceMarkerVariant.liked => (
        AppColors.fragola,
        AppStrings.placeMarkerLiked,
      ),
      PlaceMarkerVariant.userAdded => (
        AppColors.puffo,
        AppStrings.placeMarkerUserAdded,
      ),
      PlaceMarkerVariant.standard => (AppColors.fondente, 'standard'),
    };

    return Semantics(
      key: ValueKey<String>('place-marker-${entry.place.id}'),
      container: true,
      button: true,
      selected: selected,
      label:
          '${entry.place.name}, $stateLabel, ${selected ? AppStrings.selectedState : AppStrings.unselectedState}',
      excludeSemantics: true,
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            focusColor: AppFocus.color.withValues(alpha: 0.2),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(
                'assets/images/pin-fondente.svg',
                key: ValueKey<String>('marker-icon-${variant.name}'),
                height: selected ? pinHeight * selectedScale : pinHeight,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
