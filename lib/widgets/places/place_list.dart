import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../providers/flavor_search_provider.dart';
import '../../providers/places_discovery_provider.dart';
import '../melt_pin.dart';
import 'place_marker.dart';

final class PlaceList extends StatelessWidget {
  const PlaceList({
    required this.entries,
    required this.selectedPlaceId,
    required this.onSelect,
    required this.onOpenDetail,
    this.currentUid,
    this.opensOnTap = false,
    super.key,
  });

  final List<DiscoveryPlace> entries;
  final String? selectedPlaceId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenDetail;
  final String? currentUid;

  /// Without a map beside the list, tapping a row opens the place, as on iOS.
  /// With one, it selects and the chevron opens.
  final bool opensOnTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _PlaceRow(
          entry: entry,
          currentUid: currentUid,
          selected: entry.place.id == selectedPlaceId,
          opensOnTap: opensOnTap,
          onSelect: () => onSelect(entry.place.id),
          onOpen: () => onOpenDetail(entry.place.id),
        );
      },
    );
  }
}

final class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.entry,
    required this.currentUid,
    required this.selected,
    required this.opensOnTap,
    required this.onSelect,
    required this.onOpen,
  });

  final DiscoveryPlace entry;
  final String? currentUid;
  final bool selected;
  final bool opensOnTap;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final place = entry.place;
    final variant = markerVariantFor(entry, currentUid: currentUid);
    final states = <PlaceMarkerVariant>[
      if (entry.favorite) PlaceMarkerVariant.favorite,
      if (entry.saved) PlaceMarkerVariant.saved,
      if (entry.liked) PlaceMarkerVariant.liked,
      if (currentUid != null && place.addedByUid == currentUid)
        PlaceMarkerVariant.userAdded,
    ];
    final match = entry.flavorMatch;
    // Plain pins follow the ink, or they vanish on the dark surface.
    final pin = variant == PlaceMarkerVariant.standard
        ? colors.onSurface
        : placeVariantStyle(variant).color;
    final chevron = Icon(
      CupertinoIcons.chevron_forward,
      size: 20,
      color: colors.onSurfaceVariant,
    );

    return Semantics(
      key: ValueKey<String>('place-row-${place.id}'),
      container: true,
      button: true,
      selected: selected,
      label: [
        place.name,
        place.address,
        for (final state in states) placeVariantStyle(state).label!,
        if (match != null) '${match.flavorName}, ${match.bestRating} su 5',
        selected ? AppStrings.selectedState : AppStrings.unselectedState,
      ].join(', '),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onSelect();
            if (opensOnTap) onOpen();
          },
          focusColor: AppFocus.color.withValues(alpha: 0.24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MeltPinGlyph(
                          color: pin,
                          height: 38,
                          swirl: pin.computeLuminance() < 0.2
                              ? AppColors.fiorDiPanna
                              : AppColors.fondente,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                place.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                place.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (match != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                _FlavorMatchChip(match: match),
                              ],
                              if (states.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  runSpacing: AppSpacing.xxs,
                                  children: [
                                    for (final state in states)
                                      _StateTag(variant: state),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (opensOnTap)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: chevron,
                  )
                else
                  IconButton(
                    tooltip: AppStrings.placeOpenTooltip(place.name),
                    onPressed: onOpen,
                    icon: chevron,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glyph and word on the state's colour, so the colour is never alone.
final class _StateTag extends StatelessWidget {
  const _StateTag({required this.variant});

  final PlaceMarkerVariant variant;

  @override
  Widget build(BuildContext context) {
    final style = placeVariantStyle(variant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 12, color: AppColors.fondente),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                style.label!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.fondente),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill shown when a search matches a flavor tasted at this place.
/// Background comes from the flavor's color; legacy check-ins with no (or an
/// unparseable) [FlavorPlaceMatch.colorHex] fall back to the theme's
/// `onSurface` tint, so contrast holds in both light and dark theme.
final class _FlavorMatchChip extends StatelessWidget {
  const _FlavorMatchChip({required this.match});

  final FlavorPlaceMatch match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = _parseHex(match.colorHex);
    final background = parsed ?? scheme.onSurface.withValues(alpha: 0.1);
    final foreground = parsed == null ? scheme.onSurface : inkOn(background);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        AppStrings.placeFlavorMatchChip(match.flavorName, match.bestRating),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  /// Null for missing or unparseable hex — both routed to the theme-aware
  /// fallback rather than a fixed dark background with fixed dark text.
  Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
