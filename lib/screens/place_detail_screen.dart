import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../models/place.dart';
import '../models/place_aggregate.dart';
import '../models/place_state.dart';
import '../providers/auth_provider.dart';
import '../providers/place_aggregate_providers.dart';
import '../providers/place_providers.dart';
import '../utils/error_handler.dart';
import '../widgets/collection/place_editorial_cover.dart';
import '../widgets/semantic_state_button.dart';
import '../constants/app_strings.dart';

Uri buildExternalMapUri(Place place) =>
    Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '${place.location.latitude},${place.location.longitude}',
    });

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(placesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.placeDetailTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: catalog.when(
        loading: () => const _PlaceDetailLoading(),
        error: (error, _) => _CatalogRecovery(
          message: ErrorHandler.getReadableError(error),
          actionLabel: AppStrings.placeDetailRetryPlace,
          onPressed: () => ref.invalidate(placesProvider),
        ),
        data: (places) {
          final place = places
              .where((candidate) => candidate.id == placeId)
              .firstOrNull;
          if (place == null) {
            return _CatalogRecovery(
              message: AppStrings.placeNotFound,
              actionLabel: AppStrings.placeBackToList,
              onPressed: () => context.go('/places'),
            );
          }
          return _PlaceDetailContent(place: place, placeId: placeId);
        },
      ),
    );
  }
}

final class _PlaceDetailContent extends ConsumerWidget {
  const _PlaceDetailContent({required this.place, required this.placeId});

  final Place place;
  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = ResponsiveClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    final aggregate = ref.watch(placeAggregateProvider(placeId));
    final personal = ref.watch(placeStateProvider(placeId));
    final controller = ref.watch(placeStateControllerProvider);
    final currentUid = ref.watch(currentUidProvider);
    final effectiveState = personal.value;
    final canMutate = currentUid != null && personal.hasValue;

    return CustomScrollView(
      key: ValueKey<String>('place-detail-${responsive.name}-layout'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.maxContent),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  AppSpacing.md,
                  responsive.horizontalPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AspectRatio(
                      key: const ValueKey<String>('place-detail-hero'),
                      aspectRatio: responsive == ResponsiveClass.wide
                          ? 16 / 9
                          : 4 / 3,
                      child: PlaceEditorialCover(
                        placeId: place.id,
                        placeName: place.name,
                        borderRadius: AppRadii.hero,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      key: const ValueKey<String>('place-detail-metadata'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          place.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.location_on_outlined, size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(child: Text(place.address)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _AggregateRow(
                          aggregate: aggregate,
                          onRetry: () {
                            ref.invalidate(
                              placeAggregateForIdProvider(place.id),
                            );
                            ref.invalidate(placeAggregateProvider(place.id));
                          },
                        ),
                      ],
                    ),
                    if (effectiveState?.note case final note?
                        when note.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _PersonalNote(note: note),
                    ],
                    Column(
                      key: const ValueKey<String>('place-detail-actions'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          AppStrings.placeYourActions,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (personal.hasError)
                          _InlineRecovery(
                            message: AppStrings.placePersonalStateUnavailable,
                            actionLabel: AppStrings.placeRetryPersonalState,
                            onPressed: () =>
                                ref.invalidate(placeStateProvider(placeId)),
                          ),
                        _PersonalActions(
                          place: place,
                          current: effectiveState,
                          canMutate: canMutate,
                          controller: controller,
                        ),
                        if (currentUid == null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppStrings.placeLoginToSave,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _NavigationActions(place: place),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _PlaceDetailLoading extends StatelessWidget {
  const _PlaceDetailLoading();

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    final skeleton = Theme.of(context).colorScheme.surfaceContainerLow;
    Widget block({required double height, double? width}) => Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: skeleton,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    );

    return CustomScrollView(
      key: ValueKey<String>('place-detail-${responsive.name}-layout'),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.maxContent),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  AppSpacing.md,
                  responsive.horizontalPadding,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AspectRatio(
                      key: const ValueKey<String>('place-detail-hero'),
                      aspectRatio: responsive == ResponsiveClass.wide
                          ? 16 / 9
                          : 4 / 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: skeleton,
                          borderRadius: BorderRadius.circular(AppRadii.hero),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      key: const ValueKey<String>('place-detail-metadata'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        block(height: 34, width: 280),
                        const SizedBox(height: AppSpacing.xs),
                        block(height: 20, width: 220),
                        const SizedBox(height: AppSpacing.md),
                        block(height: 56),
                      ],
                    ),
                    Column(
                      key: const ValueKey<String>('place-detail-actions'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        block(height: 28, width: 180),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            block(height: AppLayout.touchTarget, width: 130),
                            block(height: AppLayout.touchTarget, width: 190),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            block(height: AppLayout.touchTarget, width: 160),
                            block(height: AppLayout.touchTarget, width: 150),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _AggregateRow extends StatelessWidget {
  const _AggregateRow({required this.aggregate, required this.onRetry});

  final AsyncValue<PlaceAggregate?> aggregate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: aggregate.when(
        loading: () => DecoratedBox(
          key: const ValueKey<String>('place-aggregate-loading'),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
        error: (_, _) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(AppStrings.placeDetailRetryRatings),
          ),
        ),
        data: (value) {
          final count = value?.checkInCount ?? 0;
          if (value == null || count == 0) {
            return const Row(
              children: <Widget>[
                Icon(Icons.star_border_rounded),
                SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(AppStrings.placeDetailNoRatings)),
                Text('0', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(width: AppSpacing.xxs),
                Text(AppStrings.placeDetailVisits),
              ],
            );
          }
          return Row(
            children: <Widget>[
              const Icon(Icons.star_rounded, color: AppColors.sorbetto),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value.ratingAverage.toStringAsFixed(1),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Text(AppStrings.placeDetailVisits),
            ],
          );
        },
      ),
    );
  }
}

final class _PersonalNote extends StatelessWidget {
  const _PersonalNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.placeYourNote,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note),
        ],
      ),
    );
  }
}

final class _PersonalActions extends ConsumerWidget {
  const _PersonalActions({
    required this.place,
    required this.current,
    required this.canMutate,
    required this.controller,
  });

  final Place place;
  final PlaceState? current;
  final bool canMutate;
  final PlaceStateControllerSnapshot controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPending = controller.hasPending(place.id, PlaceStateField.saved);
    final favoritePending = controller.hasPending(
      place.id,
      PlaceStateField.favorite,
    );
    final savedFailure = controller.failureFor(place.id, PlaceStateField.saved);
    final favoriteFailure = controller.failureFor(
      place.id,
      PlaceStateField.favorite,
    );

    Future<void> toggle(PlaceStateField field) async {
      try {
        final notifier = ref.read(placeStateControllerProvider.notifier);
        switch (field) {
          case PlaceStateField.saved:
            await notifier.toggleSaved(place.id, current: current);
          case PlaceStateField.favorite:
            await notifier.toggleFavorite(place.id, current: current);
          case PlaceStateField.liked:
            break;
        }
      } on PlaceStateFailure {
        // Canonical controller state keeps the field-specific inline failure.
      }
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: <Widget>[
        _StateActionWithFailure(
          errorKey: const ValueKey<String>('place-save-error'),
          failure: savedFailure,
          onRetry: () => unawaited(toggle(PlaceStateField.saved)),
          child: SemanticStateButton(
            key: const ValueKey<String>('place-save-action'),
            selected: current?.saved ?? false,
            selectedLabel: 'Salvata',
            unselectedLabel: 'Salva',
            selectedIcon: Icons.bookmark_rounded,
            unselectedIcon: Icons.bookmark_border_rounded,
            onPressed: !canMutate || savedPending
                ? null
                : () => unawaited(toggle(PlaceStateField.saved)),
          ),
        ),
        _StateActionWithFailure(
          errorKey: const ValueKey<String>('place-favorite-error'),
          failure: favoriteFailure,
          onRetry: () => unawaited(toggle(PlaceStateField.favorite)),
          child: SemanticStateButton(
            key: const ValueKey<String>('place-favorite-action'),
            selected: current?.favorite ?? false,
            selectedLabel: 'Preferita',
            unselectedLabel: AppStrings.placeAddToFavorites,
            selectedIcon: Icons.star_rounded,
            unselectedIcon: Icons.star_border_rounded,
            onPressed: !canMutate || favoritePending
                ? null
                : () => unawaited(toggle(PlaceStateField.favorite)),
          ),
        ),
      ],
    );
  }
}

final class _StateActionWithFailure extends StatelessWidget {
  const _StateActionWithFailure({
    required this.errorKey,
    required this.failure,
    required this.onRetry,
    required this.child,
  });

  final Key errorKey;
  final PlaceStateFailure? failure;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          child,
          if (failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              failure!.message,
              key: errorKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
          ],
        ],
      ),
    );
  }
}

final class _NavigationActions extends StatelessWidget {
  const _NavigationActions({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey<String>('place-maps-action'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, AppLayout.touchTarget),
          ),
          onPressed: () => unawaited(_openMap(context, place)),
          icon: const Icon(Icons.map_outlined),
          label: const Text(AppStrings.placeOpenInMaps),
        ),
        FilledButton.icon(
          key: const ValueKey<String>('place-check-in-action'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, AppLayout.touchTarget),
            backgroundColor: AppColors.fragola,
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.push(
            Uri(
              path: '/check-in',
              queryParameters: <String, String>{'placeId': place.id},
            ).toString(),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text(AppStrings.placeCheckinButton),
        ),
      ],
    );
  }

  Future<void> _openMap(BuildContext context, Place place) async {
    final launched = await launchUrl(
      buildExternalMapUri(place),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.placeMapsError)));
    }
  }
}

final class _InlineRecovery extends StatelessWidget {
  const _InlineRecovery({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(message),
          TextButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

final class _CatalogRecovery extends StatelessWidget {
  const _CatalogRecovery({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.storefront_outlined, size: 44),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
