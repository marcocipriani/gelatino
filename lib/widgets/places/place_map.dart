import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../../providers/location_provider.dart';
import '../../providers/places_discovery_provider.dart';
import '../melt_pin.dart';
import 'place_map_surface.dart';
import 'place_marker.dart';
import '../../constants/app_strings.dart';

final class PlaceMap extends ConsumerStatefulWidget {
  const PlaceMap({
    required this.entries,
    required this.currentUid,
    required this.selectedPlaceId,
    required this.onSelect,
    required this.onOpenDetail,
    this.query = '',
    this.filter = PlacesFilter.all,
    super.key,
  });

  final List<DiscoveryPlace> entries;
  final String? currentUid;
  final String? selectedPlaceId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onOpenDetail;

  /// What produced [entries]. When it changes the camera follows the results.
  final String query;
  final PlacesFilter filter;

  @override
  ConsumerState<PlaceMap> createState() => _PlaceMapState();
}

final class _PlaceMapState extends ConsumerState<PlaceMap> {
  static const _refitDelay = Duration(milliseconds: 250);

  final PlaceMapSurfaceController _surface = PlaceMapSurfaceController();
  late final GeoPoint _start = _medianOf(widget.entries);
  Timer? _refit;

  /// Resolved on demand, never at mount: asking for GPS the moment the map
  /// opens is a permission prompt nobody asked for.
  DeviceLocation? _deviceLocation;
  bool _locating = false;

  /// The median, unlike the first catalog row, is where most places are.
  static GeoPoint _medianOf(List<DiscoveryPlace> entries) {
    assert(entries.isNotEmpty, 'PlaceMap requires actual catalog coordinates.');
    final latitudes = [
      for (final entry in entries) entry.place.location.latitude,
    ]..sort();
    final longitudes = [
      for (final entry in entries) entry.place.location.longitude,
    ]..sort();
    final middle = entries.length ~/ 2;
    return GeoPoint(latitudes[middle], longitudes[middle]);
  }

  DiscoveryPlace? get _selected => widget.entries
      .where((entry) => entry.place.id == widget.selectedPlaceId)
      .firstOrNull;

  bool get _narrowed =>
      widget.query.trim().isNotEmpty || widget.filter != PlacesFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selected case final selected?) {
        _surface.moveTo(selected.place.location);
      } else if (_narrowed) {
        _fitResults();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query || oldWidget.filter != widget.filter) {
      // Wait for a pause in typing rather than chase every letter.
      _refit?.cancel();
      _refit = Timer(_refitDelay, _fitResults);
    } else if (oldWidget.selectedPlaceId != widget.selectedPlaceId) {
      if (_selected case final selected?) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _surface.moveTo(selected.place.location, zoom: 16);
        });
      }
    }
  }

  void _fitResults() =>
      _surface.fit([for (final entry in widget.entries) entry.place.location]);

  @override
  void dispose() {
    _refit?.cancel();
    super.dispose();
  }

  Future<void> _recentre() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final location = await ref
          .read(deviceLocationServiceProvider)
          .currentLocation();
      if (!mounted) return;
      setState(() => _deviceLocation = location);
      _surface.moveTo(GeoPoint(location.latitude, location.longitude));
    } on LocationFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: <Widget>[
            Positioned.fill(
              child: ref
                  .watch(placeMapSurfaceAdapterProvider)
                  .buildSurface(
                    context,
                    initialCoordinate: _start,
                    initialZoom: 13,
                    controller: _surface,
                    markers: <PlaceMapSurfaceMarker>[
                      for (final entry in widget.entries) _marker(entry),
                      if (_deviceLocation case final location?)
                        PlaceMapSurfaceMarker(
                          coordinate: GeoPoint(
                            location.latitude,
                            location.longitude,
                          ),
                          alignment: Alignment.center,
                          child: const _DeviceLocationDot(),
                        ),
                    ],
                    onMapTap: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (selected != null) widget.onSelect(null);
                    },
                  ),
            ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: Column(
                children: [
                  _MapButton(
                    key: const ValueKey<String>('place-map-recentre'),
                    label: AppStrings.placeMapRecenter,
                    icon: CupertinoIcons.location_fill,
                    busy: _locating,
                    onPressed: _recentre,
                  ),
                  // Pinch needs two fingers; these need one. A squeezed map
                  // gives the room to the preview instead.
                  if (constraints.maxHeight >=
                      (selected == null ? 160 : 250)) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _MapButton(
                      label: AppStrings.placeMapZoomIn,
                      icon: CupertinoIcons.plus,
                      onPressed: () => _surface.zoomBy(1),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MapButton(
                      label: AppStrings.placeMapZoomOut,
                      icon: CupertinoIcons.minus,
                      onPressed: () => _surface.zoomBy(-1),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.standard),
                reverseDuration: AppMotion.of(context, AppMotion.fast),
                switchInCurve: AppMotion.glide,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(0, 0.4), end: Offset.zero),
                    ),
                    child: child,
                  ),
                ),
                child: selected == null
                    ? const SizedBox.shrink()
                    : _PlacePreview(
                        key: ValueKey('place-preview-${selected.place.id}'),
                        entry: selected,
                        variant: markerVariantFor(
                          selected,
                          currentUid: widget.currentUid,
                        ),
                        onOpen: () => widget.onOpenDetail(selected.place.id),
                        onClose: () => widget.onSelect(null),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PlaceMapSurfaceMarker _marker(DiscoveryPlace entry) {
    final id = entry.place.id;
    final variant = markerVariantFor(entry, currentUid: widget.currentUid);
    final selected = id == widget.selectedPlaceId;
    return PlaceMapSurfaceMarker(
      id: id,
      coordinate: entry.place.location,
      width: PlaceMarker.boxWidth,
      height: PlaceMarker.boxHeight,
      clusterPriority: selected
          ? null
          : PlaceMarkerVariant.standard.index - variant.index,
      child: PlaceMarker(
        entry: entry,
        variant: variant,
        selected: selected,
        onPressed: () {
          HapticFeedback.selectionClick();
          widget.onSelect(id);
        },
      ),
    );
  }
}

final class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !busy,
      label: label,
      onTap: busy ? null : onPressed,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: label,
          onPressed: busy ? null : onPressed,
          style: IconButton.styleFrom(
            backgroundColor: colors.surface,
            disabledBackgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            fixedSize: const Size.square(AppLayout.touchTarget),
            side: BorderSide(color: colors.outline),
          ),
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Icon(icon, size: 21),
        ),
      ),
    );
  }
}

final class _PlacePreview extends StatelessWidget {
  const _PlacePreview({
    required this.entry,
    required this.variant,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final DiscoveryPlace entry;
  final PlaceMarkerVariant variant;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = variant == PlaceMarkerVariant.standard
        ? AppColors.fragola
        : placeVariantStyle(variant).color;
    return Material(
      color: colors.surface,
      elevation: AppElevation.overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                button: true,
                hint: AppStrings.placeOpenDetail,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        MeltPinGlyph(
                          color: color,
                          height: 36,
                          swirl: AppColors.fondente,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.place.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                entry.place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                AppStrings.placeOpenDetail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.accentInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: AppStrings.placeMapClosePreview,
              onPressed: onClose,
              icon: const Icon(CupertinoIcons.xmark, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deliberately not a Melt Pin: the user is not a gelateria, and a different
/// shape keeps the two readable at a glance.
final class _DeviceLocationDot extends StatelessWidget {
  const _DeviceLocationDot();

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.placeMapYouAreHere,
    child: ExcludeSemantics(
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: AppColors.fondente,
            shape: BoxShape.circle,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.puffo,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.fiorDiPanna, width: 3),
            ),
          ),
        ),
      ),
    ),
  );
}
