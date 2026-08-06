import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../providers/flavor_search_provider.dart';
import '../../providers/places_discovery_provider.dart';
import '../../theme/app_theme.dart';

final class PlaceList extends StatelessWidget {
  const PlaceList({
    required this.entries,
    required this.selectedPlaceId,
    required this.onSelect,
    required this.onOpenDetail,
    super.key,
  });

  final List<DiscoveryPlace> entries;
  final String? selectedPlaceId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final place = entry.place;
        final selected = place.id == selectedPlaceId;
        return Semantics(
          key: ValueKey<String>('place-row-${place.id}'),
          container: true,
          button: true,
          selected: selected,
          label:
              '${place.name}, ${place.address}, ${selected ? AppStrings.selectedState : AppStrings.unselectedState}',
          child: Material(
            color: selected
                ? AppColors.fragola.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelect(place.id),
              focusColor: AppFocus.color.withValues(alpha: 0.16),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            place.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (entry.flavorMatch != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _FlavorMatchChip(match: entry.flavorMatch!),
                          ],
                          if (entry.favorite || entry.saved || entry.liked) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              children: <Widget>[
                                if (entry.favorite)
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: AppColors.sorbetto,
                                  ),
                                if (entry.saved)
                                  const Icon(
                                    Icons.bookmark_rounded,
                                    size: 18,
                                    color: AppColors.menta,
                                  ),
                                if (entry.liked)
                                  const Icon(
                                    Icons.favorite_rounded,
                                    size: 18,
                                    color: AppColors.fragola,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.placeOpenTooltip(place.name),
                      onPressed: () => onOpenDetail(place.id),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final foreground = parsed == null
        ? scheme.onSurface
        : (background.computeLuminance() > 0.55
              ? AppTheme.fondenteExtra
              : Colors.white);
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
          fontSize: 12,
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
