import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../design/focus_ring.dart';
import '../../design/motion.dart';
import '../../providers/places_discovery_provider.dart';
import '../../constants/app_strings.dart';
import '../melt_pin.dart';

/// Colour, glyph and spoken name of a place state, shared by pins, list tags
/// and filters so colour is never the only cue.
({Color color, IconData? icon, String? label}) placeVariantStyle(
  PlaceMarkerVariant variant,
) => switch (variant) {
  PlaceMarkerVariant.favorite => (
    color: AppColors.sorbetto,
    icon: CupertinoIcons.star_fill,
    label: AppStrings.placeMarkerFavorite,
  ),
  PlaceMarkerVariant.saved => (
    color: AppColors.menta,
    icon: CupertinoIcons.bookmark_fill,
    label: AppStrings.placeMarkerSaved,
  ),
  PlaceMarkerVariant.liked => (
    color: AppColors.fragola,
    icon: CupertinoIcons.heart_fill,
    label: AppStrings.placeMarkerLiked,
  ),
  PlaceMarkerVariant.userAdded => (
    color: AppColors.puffo,
    icon: CupertinoIcons.plus,
    label: AppStrings.placeMarkerUserAdded,
  ),
  PlaceMarkerVariant.standard => (
    color: AppColors.fondente,
    icon: null,
    label: null,
  ),
};

/// Fondente disc with the state's glyph: at least 11:1 on tiles and on both
/// themes, which the bright fills alone can't promise.
class PlaceStateBadge extends StatelessWidget {
  const PlaceStateBadge({required this.variant, this.size = 22, super.key});

  final PlaceMarkerVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = placeVariantStyle(variant);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fondente,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.fiorDiPanna, width: 1.5),
      ),
      child: Icon(style.icon, size: size * 0.54, color: style.color),
    );
  }
}

/// Melt Pin marker. The five `pin-*.svg` brand assets share one path and differ
/// only by `fill`, so a single asset plus a `ColorFilter` renders all of them —
/// and lets the default variant pick its colour instead of baking one in.
///
/// States differ by colour, glyph and size: plain places are smaller, so the
/// user's own places lead.
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
  static const double _standardScale = 0.8;

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
    final style = placeVariantStyle(variant);
    final standard = variant == PlaceMarkerVariant.standard;
    // A selected plain pin turns Fragola, the brand's active colour.
    final color = selected && standard ? AppColors.fragola : style.color;
    final scale = selected ? selectedScale : (standard ? _standardScale : 1.0);

    return Semantics(
      key: ValueKey<String>('place-marker-${entry.place.id}'),
      container: true,
      button: true,
      selected: selected,
      onTap: onPressed,
      label: [
        entry.place.name,
        ?style.label,
        selected ? AppStrings.selectedState : AppStrings.unselectedState,
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        width: boxWidth,
        height: boxHeight,
        child: AppFocusRing(
          borderRadius: AppRadii.pill,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedScale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  duration: AppMotion.of(context, AppMotion.standard),
                  curve: AppMotion.glide,
                  child: SizedBox(
                    width: pinWidth,
                    height: pinHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: MeltPinGlyph(
                            color: color,
                            height: pinHeight,
                            swirl: color == AppColors.fondente
                                ? AppColors.fiorDiPanna
                                : AppColors.fondente,
                            artKey: ValueKey<String>(
                              'marker-icon-${variant.name}',
                            ),
                          ),
                        ),
                        if (!standard)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: PlaceStateBadge(variant: variant, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for pins too close to tell apart. Fragola, with that state's
/// glyph, when one of the user's own places is inside.
final class PlaceClusterMarker extends StatelessWidget {
  const PlaceClusterMarker({
    required this.count,
    required this.ownVariant,
    required this.onPressed,
    super.key,
  });

  final int count;
  final PlaceMarkerVariant? ownVariant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final includesOwn = ownVariant != null;
    final fill = includesOwn ? AppColors.fragola : AppColors.fondente;
    final ink = includesOwn ? AppColors.fondente : AppColors.fiorDiPanna;
    final size = count >= 100
        ? 54.0
        : count >= 10
        ? 48.0
        : 44.0;
    return Semantics(
      container: true,
      button: true,
      label: AppStrings.placeClusterSemantic(count, includesOwn: includesOwn),
      onTap: onPressed,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AppFocusRing(
          borderRadius: AppRadii.pill,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox.square(
                dimension: size,
                child: Material(
                  color: fill,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.fiorDiPanna, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    child: Center(
                      child: Text(
                        '$count',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: ink,
                          fontSize: count >= 1000 ? 13 : 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (ownVariant case final variant?)
                Positioned(
                  top: -5,
                  right: -5,
                  child: IgnorePointer(
                    child: PlaceStateBadge(variant: variant, size: 21),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
