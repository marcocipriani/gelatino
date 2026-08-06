import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../providers/auth_provider.dart';
import '../providers/place_providers.dart';
import '../providers/places_discovery_provider.dart';
import '../providers/profile_providers.dart';
import '../utils/error_handler.dart';
import '../widgets/places/add_place_dialog.dart';
import '../widgets/places/place_action_bar.dart';
import '../widgets/places/place_filter_bar.dart';
import '../widgets/places/place_list.dart';
import '../widgets/places/place_map.dart';
import '../widgets/places/place_search_bar.dart';
import '../constants/app_strings.dart';

class PlacesTab extends ConsumerStatefulWidget {
  const PlacesTab({super.key});

  @override
  ConsumerState<PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends ConsumerState<PlacesTab> {
  final TextEditingController _searchController = TextEditingController();
  ProviderSubscription<String?>? _defaultViewSubscription;
  String? _inlineMessage;

  @override
  void initState() {
    super.initState();
    _defaultViewSubscription = ref.listenManual<String?>(
      defaultCollectionViewProvider,
      (_, next) => _applyDefaultAfterBuild(next),
    );
    _applyDefaultAfterBuild(ref.read(defaultCollectionViewProvider));
  }

  void _applyDefaultAfterBuild(String? value) {
    if (value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(placesDiscoveryControllerProvider.notifier)
          .applyLoadedDefault(value);
    });
  }

  @override
  void dispose() {
    _defaultViewSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(placesDiscoveryDataProvider);
    final interaction = ref.watch(placesDiscoveryControllerProvider);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveClass.fromWidth(constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxContent,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.horizontalPadding,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    key: ValueKey<String>('places-${responsive.name}-layout'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(
                        context,
                        uid,
                        discovery.value ?? const <DiscoveryPlace>[],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PlaceSearchBar(
                        controller: _searchController,
                        onChanged: (query) => ref
                            .read(placesDiscoveryControllerProvider.notifier)
                            .setQuery(query),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PlaceFilterBar(
                        selected: interaction.filter,
                        authenticated: uid != null,
                        onSelected: (filter) {
                          setState(() => _inlineMessage = null);
                          ref
                              .read(placesDiscoveryControllerProvider.notifier)
                              .setFilter(filter);
                        },
                        onPrivateFilterRequiresLogin: () => setState(
                          () => _inlineMessage =
                              AppStrings.placesLoginForFilters,
                        ),
                      ),
                      if (_inlineMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _inlineMessage!,
                          key: const ValueKey<String>('places-inline-message'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      if (responsive != ResponsiveClass.wide) ...<Widget>[
                        PlaceActionBar(
                          mode: interaction.viewMode,
                          onChanged: (mode) => ref
                              .read(placesDiscoveryControllerProvider.notifier)
                              .chooseView(mode),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Expanded(
                        child: _buildDiscoveryBody(
                          context,
                          responsive: responsive,
                          discovery: discovery,
                          interaction: interaction,
                          currentUid: uid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String? uid,
    List<DiscoveryPlace> entries,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Gelaterie',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                AppStrings.placesSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          key: const ValueKey<String>('add-place-action'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, AppLayout.touchTarget),
            backgroundColor: AppColors.fragola,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
          onPressed: () {
            if (uid == null) {
              setState(
                () => _inlineMessage = AppStrings.placesLoginToAdd,
              );
              return;
            }
            _showAddPlaceDialog(entries);
          },
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text(AppStrings.add),
        ),
      ],
    );
  }

  Widget _buildDiscoveryBody(
    BuildContext context, {
    required ResponsiveClass responsive,
    required AsyncValue<List<DiscoveryPlace>> discovery,
    required PlacesDiscoveryState interaction,
    required String? currentUid,
  }) {
    return discovery.when(
      loading: () => _PlacesLoadingGeometry(wide: responsive.isWide),
      error: (error, _) => _PlacesRecoveryState(
        icon: Icons.cloud_off_rounded,
        message: ErrorHandler.getReadableError(error),
        actionLabel: AppStrings.retry,
        onPressed: _retryDiscovery,
      ),
      data: (entries) {
        if (entries.isEmpty) {
          final catalogIsEmpty =
              interaction.query.trim().isEmpty &&
              interaction.filter == PlacesFilter.all;
          if (catalogIsEmpty) {
            return _PlacesRecoveryState(
              icon: Icons.storefront_outlined,
              message: currentUid == null
                  ? AppStrings.placesLoginToAddFirst
                  : AppStrings.placesCatalogEmpty,
              actionLabel: currentUid == null ? AppStrings.login : AppStrings.placeAddButton,
              onPressed: currentUid == null
                  ? () => context.go('/login')
                  : () => _showAddPlaceDialog(const <DiscoveryPlace>[]),
            );
          }
          return _PlacesRecoveryState(
            icon: Icons.search_off_rounded,
            message: AppStrings.placesNoSearchMatch,
            actionLabel: AppStrings.placesClearFilters,
            onPressed: () {
              _searchController.clear();
              ref
                  .read(placesDiscoveryControllerProvider.notifier)
                  .resetFilters();
            },
          );
        }

        void select(String placeId) => ref
            .read(placesDiscoveryControllerProvider.notifier)
            .selectPlace(placeId);
        void open(String placeId) =>
            context.push('/place/${Uri.encodeComponent(placeId)}');
        Widget list() => PlaceList(
          entries: entries,
          selectedPlaceId: interaction.selectedPlaceId,
          onSelect: select,
          onOpenDetail: open,
        );
        Widget map() => PlaceMap(
          entries: entries,
          currentUid: currentUid,
          selectedPlaceId: interaction.selectedPlaceId,
          onSelect: select,
          onOpenDetail: open,
        );

        if (responsive.isWide) {
          final available = MediaQuery.sizeOf(
            context,
          ).width.clamp(0, AppLayout.maxContent);
          final listWidth = available >= 1200 ? 520.0 : 400.0;
          final gap = available >= 1200 ? AppSpacing.xl : AppSpacing.lg;
          return Row(
            children: <Widget>[
              SizedBox(
                key: const ValueKey<String>('places-list-pane'),
                width: listWidth,
                child: list(),
              ),
              SizedBox(width: gap),
              Expanded(
                child: SizedBox(
                  key: const ValueKey<String>('places-map-pane'),
                  child: map(),
                ),
              ),
            ],
          );
        }

        return switch (interaction.viewMode) {
          PlacesViewMode.list => SizedBox(
            key: const ValueKey<String>('places-list-pane'),
            child: list(),
          ),
          PlacesViewMode.map => SizedBox(
            key: const ValueKey<String>('places-map-pane'),
            child: map(),
          ),
        };
      },
    );
  }

  void _retryDiscovery() {
    ref.invalidate(placesProvider);
    ref.invalidate(likedPlacesProvider);
    ref.invalidate(favoritePlacesProvider);
    ref.invalidate(savedPlacesProvider);
    ref.invalidate(placesDiscoveryDataProvider);
  }

  Future<void> _showAddPlaceDialog(List<DiscoveryPlace> entries) async {
    final created = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPlaceDialog(
        catalogCoordinates: entries
            .map((entry) => entry.place.location)
            .toList(growable: false),
      ),
    );
    if (created != null && mounted) {
      setState(() => _inlineMessage = AppStrings.placeAdded);
    }
  }
}

extension on ResponsiveClass {
  bool get isWide => this == ResponsiveClass.wide;
}

final class _PlacesLoadingGeometry extends StatelessWidget {
  const _PlacesLoadingGeometry({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerLow;
    Widget block() => DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!wide) {
          return SizedBox(
            key: const ValueKey<String>('places-loading-skeleton'),
            child: block(),
          );
        }
        final listWidth = constraints.maxWidth >= 1200 ? 520.0 : 400.0;
        final gap = constraints.maxWidth >= 1200
            ? AppSpacing.xl
            : AppSpacing.lg;
        return Row(
          key: const ValueKey<String>('places-loading-skeleton'),
          children: <Widget>[
            SizedBox(
              key: const ValueKey<String>('places-loading-list-pane'),
              width: listWidth,
              child: block(),
            ),
            SizedBox(width: gap),
            Expanded(
              child: SizedBox(
                key: const ValueKey<String>('places-loading-map-pane'),
                child: block(),
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _PlacesRecoveryState extends StatelessWidget {
  const _PlacesRecoveryState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
