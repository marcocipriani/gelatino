import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../models/place.dart';
import '../providers/auth_provider.dart';
import '../providers/place_providers.dart';
import '../utils/error_handler.dart';
import '../widgets/app_page.dart';
import '../widgets/collection/saved_place_cards.dart';
import '../widgets/editorial_header.dart';
import '../widgets/skeleton_loader.dart';
import '../constants/app_strings.dart';

/// Personal collection of saved gelaterie, with favorite flavors secondary.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final savedPlaces = ref.watch(savedPlacesProvider);
    final count = savedPlaces.value?.length;

    return Scaffold(
      body: SafeArea(
        child: AppPage(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    EditorialHeader(
                      title: AppStrings.collectionTitle,
                      description: count == null ? null : _savedCount(count),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (uid == null)
                      _UnauthenticatedCollection(
                        onLogin: () => context.go('/login'),
                      )
                    else
                      savedPlaces.when(
                        data: (places) => places.isEmpty
                            ? _EmptyCollection(
                                onExplore: () => context.go('/places'),
                              )
                            : _SavedPlacesLayout(
                                places: places,
                                onOpen: (place) => context.push(
                                  Uri(
                                    pathSegments: ['', 'place', place.id],
                                  ).toString(),
                                ),
                              ),
                        loading: () => const _CollectionSkeleton(),
                        error: (error, stackTrace) => _CollectionError(
                          error: error,
                          onRetry: () => ref.invalidate(savedPlacesProvider),
                        ),
                      ),
                    if (uid != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _FavoriteFlavorsSection(
                        onOpen: () => context.go('/favorite-flavors'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.display),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _savedCount(int count) =>
    AppStrings.savedPlacesCount(count);

class _SavedPlacesLayout extends StatelessWidget {
  const _SavedPlacesLayout({required this.places, required this.onOpen});

  final List<Place> places;
  final ValueChanged<Place> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveClass.fromWidth(
          MediaQuery.sizeOf(context).width,
        );
        final featured = places.first;
        final remaining = places.skip(1).toList(growable: false);
        final introduction = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.wishlistLabel,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.collectionSavedSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );

        if (responsive == ResponsiveClass.wide) {
          return Column(
            key: const ValueKey('collection-wide-layout'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              introduction,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: FeaturedSavedPlaceCard(
                      place: featured,
                      onOpen: () => onOpen(featured),
                    ),
                  ),
                  if (remaining.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 5,
                      child: _WideRemainingGrid(
                        places: remaining,
                        onOpen: onOpen,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        return Column(
          key: ValueKey(
            responsive == ResponsiveClass.compact
                ? 'collection-compact-layout'
                : 'collection-medium-layout',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            introduction,
            FeaturedSavedPlaceCard(
              place: featured,
              onOpen: () => onOpen(featured),
            ),
            if (remaining.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.collectionOtherPlaces,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                key: const ValueKey('collection-remaining-strip'),
                height: 420,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: remaining.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final place = remaining[index];
                    return RemainingSavedPlaceCard(
                      place: place,
                      width: 220,
                      onOpen: () => onOpen(place),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FavoriteFlavorsSection extends StatelessWidget {
  const _FavoriteFlavorsSection({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('favorite-flavors-section'),
      margin: EdgeInsets.zero,
      elevation: AppElevation.flat,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: const Icon(Icons.icecream_outlined),
        title: const Text(AppStrings.collectionFavoriteFlavorsTitle),
        subtitle: const Text(AppStrings.collectionFavoriteFlavorsSubtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onOpen,
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return _CollectionMessage(
      icon: Icons.bookmark_border,
      title: AppStrings.collectionEmptyTitle,
      description: AppStrings.collectionEmptyDesc,
      action: FilledButton.icon(
        onPressed: onExplore,
        icon: const Icon(Icons.explore_outlined),
        label: const Text(AppStrings.collectionExploreButton),
      ),
    );
  }
}

class _CollectionError extends StatelessWidget {
  const _CollectionError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CollectionMessage(
      icon: Icons.error_outline,
      title: AppStrings.collectionErrorTitle,
      description: ErrorHandler.getReadableError(error),
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text(AppStrings.retry),
      ),
    );
  }
}

class _UnauthenticatedCollection extends StatelessWidget {
  const _UnauthenticatedCollection({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _CollectionMessage(
      icon: Icons.lock_outline,
      title: AppStrings.collectionUnauthTitle,
      description: AppStrings.collectionUnauthDesc,
      action: FilledButton(onPressed: onLogin, child: const Text(AppStrings.login)),
    );
  }
}

class _CollectionMessage extends StatelessWidget {
  const _CollectionMessage({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.readableText),
          child: Column(
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionSkeleton extends StatelessWidget {
  const _CollectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveClass.fromWidth(
          MediaQuery.sizeOf(context).width,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 150, height: 28),
            const SizedBox(height: AppSpacing.xs),
            const SkeletonBox(width: 280, height: 20),
            const SizedBox(height: AppSpacing.lg),
            if (responsive == ResponsiveClass.wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: const _FeaturedSavedPlaceCardSkeleton(),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(flex: 5, child: const _WideRemainingGridSkeleton()),
                ],
              )
            else ...[
              const _FeaturedSavedPlaceCardSkeleton(),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                key: const ValueKey('collection-skeleton-remaining'),
                width: 220,
                height: 420,
                child: const _RemainingSavedPlaceCardSkeleton(
                  width: 220,
                  coverKey: ValueKey('collection-skeleton-remaining-cover'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedSavedPlaceCardSkeleton extends StatelessWidget {
  const _FeaturedSavedPlaceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact =
        ResponsiveClass.fromWidth(MediaQuery.sizeOf(context).width) ==
        ResponsiveClass.compact;
    return Card(
      key: const ValueKey('collection-skeleton-featured'),
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
          AspectRatio(
            key: const ValueKey('collection-skeleton-featured-cover'),
            aspectRatio: 16 / 10,
            child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonTextLine(
                  width: 220,
                  style: theme.textTheme.headlineSmall,
                  lines: compact ? 2 : 1,
                ),
                const SizedBox(height: AppSpacing.xs),
                _SkeletonTextLine(
                  width: 280,
                  style: theme.textTheme.bodyMedium,
                  lines: compact ? 2 : 1,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: SkeletonBox(width: 44, height: 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideRemainingGridSkeleton extends StatelessWidget {
  const _WideRemainingGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Column(
          key: const ValueKey('collection-skeleton-remaining'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonTextLine(
              width: 180,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (var index = 0; index < 2; index++)
                  _RemainingSavedPlaceCardSkeleton(width: cardWidth),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RemainingSavedPlaceCardSkeleton extends StatelessWidget {
  const _RemainingSavedPlaceCardSkeleton({required this.width, this.coverKey});

  final double width;
  final Key? coverKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
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
            AspectRatio(
              key: coverKey,
              aspectRatio: 16 / 10,
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonTextLine(
                    width: 170,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _SkeletonTextLine(
                    width: 150,
                    style: theme.textTheme.bodySmall,
                    lines: 2,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: SkeletonBox(width: 44, height: 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTextLine extends StatelessWidget {
  const _SkeletonTextLine({
    required this.width,
    required this.style,
    this.lines = 1,
  });

  final double width;
  final TextStyle? style;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: Text(
              lines == 1 ? 'Testo' : 'Testo\nTesto',
              maxLines: lines,
              style: style,
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: width, height: 12),
          ),
        ),
      ],
    );
  }
}

class _WideRemainingGrid extends StatelessWidget {
  const _WideRemainingGrid({required this.places, required this.onOpen});

  final List<Place> places;
  final ValueChanged<Place> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 460 ? 2 : 1;
        final cardWidth =
            (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
        return Column(
          key: const ValueKey('collection-wide-remaining-grid'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.collectionOtherPlaces,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final place in places)
                  RemainingSavedPlaceCard(
                    place: place,
                    width: cardWidth,
                    onOpen: () => onOpen(place),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
