import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../providers/location_provider.dart';
import '../../providers/places_discovery_provider.dart';
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
    super.key,
  });

  final List<DiscoveryPlace> entries;
  final String? currentUid;
  final String? selectedPlaceId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenDetail;

  @override
  ConsumerState<PlaceMap> createState() => _PlaceMapState();
}

final class _PlaceMapState extends ConsumerState<PlaceMap> {
  final PlaceMapSurfaceController _surface = PlaceMapSurfaceController();

  /// Resolved on demand, never at mount: asking for GPS the moment the map
  /// opens is a permission prompt nobody asked for.
  DeviceLocation? _deviceLocation;
  bool _locating = false;

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
    assert(
      widget.entries.isNotEmpty,
      'PlaceMap requires actual catalog coordinates.',
    );
    final first = widget.entries.first.place.location;
    final selected = widget.entries
        .where((entry) => entry.place.id == widget.selectedPlaceId)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Stack(
        children: <Widget>[
          ref
              .watch(placeMapSurfaceAdapterProvider)
              .buildSurface(
                context,
                initialCoordinate: first,
                initialZoom: 13,
                controller: _surface,
                markers: <PlaceMapSurfaceMarker>[
                  for (final entry in widget.entries)
                    PlaceMapSurfaceMarker(
                      coordinate: entry.place.location,
                      width: PlaceMarker.boxWidth,
                      height: PlaceMarker.boxHeight,
                      child: _marker(entry),
                    ),
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
                onMapTap: null,
              ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Semantics(
              key: const ValueKey<String>('place-map-recentre'),
              button: true,
              label: AppStrings.placeMapRecenter,
              child: ExcludeSemantics(
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: AppStrings.placeMapRecenter,
                  onPressed: _locating ? null : _recentre,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
            ),
          ),
          if (selected != null)
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.control),
                elevation: AppElevation.overlay,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          selected.place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onOpenDetail(selected.place.id),
                        child: const Text(AppStrings.placeOpenDetail),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _marker(DiscoveryPlace entry) => PlaceMarker(
    entry: entry,
    variant: markerVariantFor(entry, currentUid: widget.currentUid),
    selected: entry.place.id == widget.selectedPlaceId,
    onPressed: () => widget.onSelect(entry.place.id),
  );
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
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.puffo,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.surface,
              width: 3),
          ),
        ),
      ),
    ),
  );
}
