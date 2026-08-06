import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../models/place.dart';
import 'place_editorial_cover.dart';
import 'saved_place_control.dart';

class FeaturedSavedPlaceCard extends StatelessWidget {
  const FeaturedSavedPlaceCard({
    required this.place,
    required this.onOpen,
    super.key,
  });

  final Place place;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('featured-place-card'),
      margin: EdgeInsets.zero,
      elevation: AppElevation.flat,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.hero),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('featured-place-content'),
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: PlaceEditorialCover(
                    placeId: place.id,
                    placeName: place.name,
                    borderRadius: 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        place.address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: SavedPlaceControl(place: place),
            ),
          ),
        ],
      ),
    );
  }
}

class RemainingSavedPlaceCard extends StatelessWidget {
  const RemainingSavedPlaceCard({
    required this.place,
    required this.onOpen,
    this.width,
    super.key,
  });

  final Place place;
  final VoidCallback onOpen;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      key: ValueKey<String>('remaining-card-${place.id}'),
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: AppElevation.flat,
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: PlaceEditorialCover(
                      placeId: place.id,
                      placeName: place.name,
                      borderRadius: 0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          place.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: SavedPlaceControl(place: place),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
