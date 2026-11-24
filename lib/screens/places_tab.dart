import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/motion.dart';
import '../design/responsive.dart';
import '../models/place.dart';
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
  final FocusNode _searchFocus = FocusNode();
  String? _inlineMessage;
  bool _inlineIsError = true;

  @override
  void initState() {
    super.initState();
    // The query outlives this tab; an empty field over filtered results lies.
    _searchController.text = ref.read(placesDiscoveryControllerProvider).query;
    _searchFocus.addListener(_onSearchFocus);
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

  void _onSearchFocus() => setState(() {});

  @override
  void dispose() {
    _searchFocus
      ..removeListener(_onSearchFocus)
      ..dispose();
    _defaultViewSubscription?.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discovery = ref.watch(placesDiscoveryDataProvider);
    final interaction = ref.watch(placesDiscoveryControllerProvider);
    final uid = ref.watch(currentUidProvider);
    final controller = ref.read(placesDiscoveryControllerProvider.notifier);
    // "Azzera filtri" and account changes edit the query behind the field.
    ref.listen(
      placesDiscoveryControllerProvider.select((state) => state.query),
      (_, query) {
        if (query != _searchController.text) _searchController.text = query;
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveClass.fromWidth(constraints.maxWidth);
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final searching = _searchFocus.hasFocus;
            // The title yields to content: while searching, in landscape, and
            // at type sizes where it would push the results off screen.
            final showTitle =
                !(searching && !responsive.isWide) &&
                constraints.maxHeight >= 440 * textScale.clamp(1.0, 2.0);
            // Small phone, keyboard up: the tab bar rides on the keyboard and
            // leaves ~180pt. Only the field and its results fit in that.
            final onlySearchFits = constraints.maxHeight < 260;
            final toggleBesideFilters =
                responsive == ResponsiveClass.medium &&
                constraints.maxHeight < 440;
            final entries = discovery.value ?? const <DiscoveryPlace>[];
            final toggle = PlaceActionBar(
              mode: interaction.viewMode,
              onChanged: controller.chooseView,
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxContent,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.horizontalPadding,
                    showTitle ? AppSpacing.md : AppSpacing.xs,
                    responsive.horizontalPadding,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    key: ValueKey<String>('places-${responsive.name}-layout'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (showTitle) ...<Widget>[
                        _buildHeader(context, uid, entries, discovery.hasValue),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      KeyedSubtree(
                        // Keeps focus while the rows around it come and go.
                        key: const ValueKey<String>('places-search-row'),
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.5,
                          child: PlaceSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            searching: searching,
                            trailing: showTitle
                                ? null
                                : _addButton(uid, entries, compact: true),
                            onChanged: controller.setQuery,
                          ),
                        ),
                      ),
                      if (discovery.hasValue)
                        // Spoken as results change, with or without a title.
                        Semantics(
                          container: true,
                          liveRegion: true,
                          label: AppStrings.placeResultsCount(entries.length),
                          child: const SizedBox(height: 1, width: 1),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      if (!onlySearchFits)
                        Row(
                          children: [
                            Expanded(
                              child: PlaceFilterBar(
                                selected: interaction.filter,
                                authenticated: uid != null,
                                onSelected: (filter) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _inlineMessage = null);
                                  controller.setFilter(filter);
                                },
                                onPrivateFilterRequiresLogin: () => _showInline(
                                  AppStrings.placesLoginForFilters,
                                ),
                              ),
                            ),
                            if (toggleBesideFilters) ...[
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(width: 220, child: toggle),
                            ],
                          ],
                        ),
                      if (_inlineMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _inlineMessage!,
                            key: const ValueKey<String>(
                              'places-inline-message',
                            ),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: _inlineIsError
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      if (!onlySearchFits &&
                          !responsive.isWide &&
                          !toggleBesideFilters) ...<Widget>[
                        toggle,
                        const SizedBox(height: AppSpacing.xs),
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

  void _showInline(String message, {bool isError = true}) => setState(() {
    _inlineMessage = message;
    _inlineIsError = isError;
  });

  Widget _buildHeader(
    BuildContext context,
    String? uid,
    List<DiscoveryPlace> entries,
    bool hasCount,
  ) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Gelaterie', style: text.displaySmall),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    hasCount
                        ? AppStrings.placeResultsCount(entries.length)
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _addButton(
            uid,
            entries,
            compact:
                constraints.maxWidth /
                    MediaQuery.textScalerOf(context).scale(1) <
                300,
          ),
        ],
      ),
    );
  }

  Widget _addButton(
    String? uid,
    List<DiscoveryPlace> entries, {
    required bool compact,
  }) {
    const key = ValueKey<String>('add-place-action');
    const icon = Icon(CupertinoIcons.plus, size: 20);
    void add() {
      if (uid == null) {
        _showInline(AppStrings.placesLoginToAdd);
        return;
      }
      _showAddPlaceDialog(entries);
    }

    return compact
        ? IconButton.filled(
            key: key,
            tooltip: AppStrings.add,
            onPressed: add,
            icon: icon,
          )
        : FilledButton.icon(
            key: key,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, AppLayout.touchTarget),
            ),
            onPressed: add,
            icon: icon,
            label: Text(AppStrings.add),
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
        icon: CupertinoIcons.wifi_slash,
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
              icon: CupertinoIcons.map_pin_ellipse,
              message: currentUid == null
                  ? AppStrings.placesLoginToAddFirst
                  : AppStrings.placesCatalogEmpty,
              actionLabel: currentUid == null
                  ? AppStrings.login
                  : AppStrings.placeAddButton,
              onPressed: currentUid == null
                  ? () => context.go('/login')
                  : () => _showAddPlaceDialog(const <DiscoveryPlace>[]),
            );
          }
          return _PlacesRecoveryState(
            icon: CupertinoIcons.search,
            message: interaction.query.trim().isEmpty
                ? AppStrings.placesNoSearchMatch
                : AppStrings.placesNoMatchFor(interaction.query.trim()),
            actionLabel: AppStrings.placesClearFilters,
            onPressed: () {
              _searchController.clear();
              ref
                  .read(placesDiscoveryControllerProvider.notifier)
                  .resetFilters();
            },
          );
        }

        void select(String? placeId) => ref
            .read(placesDiscoveryControllerProvider.notifier)
            .selectPlace(placeId);
        void open(String placeId) {
          _searchFocus.unfocus();
          context.push('/place/${Uri.encodeComponent(placeId)}');
        }

        Widget list() => PlaceList(
          // A new search starts from its best match, not the old offset.
          key: ValueKey((interaction.query, interaction.filter)),
          entries: entries,
          currentUid: currentUid,
          opensOnTap: !responsive.isWide,
          selectedPlaceId: interaction.selectedPlaceId,
          onSelect: select,
          onOpenDetail: open,
        );
        Widget map() => PlaceMap(
          entries: entries,
          currentUid: currentUid,
          query: interaction.query,
          filter: interaction.filter,
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

        // Fade the new pane in; cross-fading would keep two maps alive.
        return TweenAnimationBuilder<double>(
          key: ValueKey<PlacesViewMode>(interaction.viewMode),
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.enter,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: switch (interaction.viewMode) {
            PlacesViewMode.list => SizedBox(
              key: const ValueKey<String>('places-list-pane'),
              child: list(),
            ),
            PlacesViewMode.map => SizedBox(
              key: const ValueKey<String>('places-map-pane'),
              child: map(),
            ),
          },
        );
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
    _searchFocus.unfocus();
    final created = await showModalBottomSheet<Place>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      // A form mid-GPS or mid-save mustn't be swiped away.
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: AppMotion.reduced(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (_) => AddPlaceDialog(
        catalogCoordinates: entries
            .map((entry) => entry.place.location)
            .toList(growable: false),
      ),
    );
    if (created != null && mounted) {
      _showInline(AppStrings.placeAdded, isError: false);
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
    final color = Theme.of(context).colorScheme.surfaceContainer;
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
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 40,
              color: Theme.of(context).colorScheme.accentInk,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
