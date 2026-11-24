import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../../providers/places_discovery_provider.dart';
import 'place_marker.dart';
import 'place_marker_clustering.dart';

final placeMapSurfaceAdapterProvider = Provider<PlaceMapSurfaceAdapter>(
  (_) => const FlutterPlaceMapSurfaceAdapter(),
);

final class PlaceMapSurfaceMarker {
  const PlaceMapSurfaceMarker({
    required this.coordinate,
    required this.child,
    this.width = AppLayout.touchTarget,
    this.height = AppLayout.touchTarget,
    this.alignment = Alignment.topCenter,
    this.id,
    this.clusterPriority,
  });

  /// Keeps a pin's animation state on that pin while the layer culls others.
  final String? id;

  /// Null never clusters (selection, location dot). Otherwise higher numbers
  /// anchor groups; above zero means it is one of the user's own places.
  final int? clusterPriority;

  final GeoPoint coordinate;
  final Widget child;
  final double width;
  final double height;

  /// Pins are drop-shaped, so the default hangs the widget above its
  /// coordinate and puts the tip on the point. Symmetric markers — a location
  /// dot — pass [Alignment.center] instead.
  final Alignment alignment;
}

/// Lets a caller recentre a surface it does not own, without importing
/// flutter_map. The surface attaches itself on mount; calls made while nothing
/// is attached are dropped, which is what a recentre before first layout means.
final class PlaceMapSurfaceController {
  void Function(GeoPoint coordinate, double zoom)? _move;
  void Function(List<GeoPoint> coordinates)? _fit;
  void Function(double delta)? _zoomBy;

  void attach(
    void Function(GeoPoint coordinate, double zoom) move, {
    void Function(List<GeoPoint> coordinates)? fit,
    void Function(double delta)? zoomBy,
  }) {
    _move = move;
    _fit = fit;
    _zoomBy = zoomBy;
  }

  void detach() {
    _move = null;
    _fit = null;
    _zoomBy = null;
  }

  /// Frames every coordinate.
  void fit(List<GeoPoint> coordinates) {
    if (coordinates.isNotEmpty) _fit?.call(coordinates);
  }

  void zoomBy(double delta) => _zoomBy?.call(delta);

  bool get isAttached => _move != null;

  void moveTo(GeoPoint coordinate, {double zoom = 15}) =>
      _move?.call(coordinate, zoom);
}

abstract interface class PlaceMapSurfaceAdapter {
  Widget buildSurface(
    BuildContext context, {
    required GeoPoint initialCoordinate,
    required double initialZoom,
    required List<PlaceMapSurfaceMarker> markers,
    required ValueChanged<GeoPoint>? onMapTap,
    PlaceMapSurfaceController? controller,
  });
}

final class FlutterPlaceMapSurfaceAdapter implements PlaceMapSurfaceAdapter {
  const FlutterPlaceMapSurfaceAdapter();

  @override
  Widget buildSurface(
    BuildContext context, {
    required GeoPoint initialCoordinate,
    required double initialZoom,
    required List<PlaceMapSurfaceMarker> markers,
    required ValueChanged<GeoPoint>? onMapTap,
    PlaceMapSurfaceController? controller,
  }) => _FlutterMapSurface(
    initialCoordinate: initialCoordinate,
    initialZoom: initialZoom,
    markers: markers,
    onMapTap: onMapTap,
    controller: controller,
  );
}

/// Stateful only to own the [MapController]: building one per `build` would
/// leak a controller on every rebuild.
final class _FlutterMapSurface extends StatefulWidget {
  const _FlutterMapSurface({
    required this.initialCoordinate,
    required this.initialZoom,
    required this.markers,
    required this.onMapTap,
    required this.controller,
  });

  final GeoPoint initialCoordinate;
  final double initialZoom;
  final List<PlaceMapSurfaceMarker> markers;
  final ValueChanged<GeoPoint>? onMapTap;
  final PlaceMapSurfaceController? controller;

  @override
  State<_FlutterMapSurface> createState() => _FlutterMapSurfaceState();
}

final class _FlutterMapSurfaceState extends State<_FlutterMapSurface>
    with SingleTickerProviderStateMixin {
  static const double _minZoom = 2;
  static const double _maxZoom = 19;

  /// Past this every pin stands alone, even two on the same corner.
  static const double _declutterBelow = 18.5;
  static const Size _markerSpacing = Size(
    PlaceMarker.boxWidth + 2,
    PlaceMarker.boxHeight + 2,
  );

  final MapController _map = MapController();
  late final AnimationController _flight;
  VoidCallback? _flightStep;
  VoidCallback? _whenReady;
  bool _ready = false;

  double? _groupedZoom;
  List<List<PlaceMapSurfaceMarker>> _groups = const [];

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(vsync: this, duration: AppMotion.emphasized)
      ..addListener(() => _flightStep?.call());
    _attach(widget.controller);
  }

  void _attach(PlaceMapSurfaceController? controller) =>
      controller?.attach(_move, fit: _fit, zoomBy: _zoomBy);

  @override
  void didUpdateWidget(covariant _FlutterMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _groupedZoom = null;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _flight.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onReady() {
    _ready = true;
    final pending = _whenReady;
    _whenReady = null;
    if (pending == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) pending();
    });
  }

  void _move(GeoPoint coordinate, double zoom) {
    if (!_ready) {
      _whenReady = () => _move(coordinate, zoom);
      return;
    }
    _flyTo(LatLng(coordinate.latitude, coordinate.longitude), zoom);
  }

  void _zoomBy(double delta) {
    if (_ready) _flyTo(_map.camera.center, _map.camera.zoom + delta);
  }

  void _fit(List<GeoPoint> coordinates, {double maxZoom = 16}) {
    if (!_ready) {
      _whenReady = () => _fit(coordinates, maxZoom: maxZoom);
      return;
    }
    final size = _map.camera.nonRotatedSize;
    final target = CameraFit.coordinates(
      coordinates: [
        for (final point in coordinates)
          LatLng(point.latitude, point.longitude),
      ],
      // Proportional, so a squeezed map never gets a negative viewport.
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.15,
        vertical: size.height * 0.2,
      ),
      maxZoom: maxZoom,
    ).fit(_map.camera);
    _flyTo(target.center, target.zoom);
  }

  void _flyTo(LatLng center, double zoom) {
    final targetZoom = zoom.clamp(_minZoom, _maxZoom);
    _flight.stop();
    if (AppMotion.reduced(context)) {
      _map.move(center, targetZoom);
      return;
    }
    final fromCenter = _map.camera.center;
    final fromZoom = _map.camera.zoom;
    _flightStep = () {
      final t = AppMotion.glide.transform(_flight.value);
      _map.move(
        LatLng(
          fromCenter.latitude + (center.latitude - fromCenter.latitude) * t,
          fromCenter.longitude + (center.longitude - fromCenter.longitude) * t,
        ),
        fromZoom + (targetZoom - fromZoom) * t,
      );
    };
    _flight.forward(from: 0);
  }

  /// A finger on the map always wins over a camera animation.
  void _interrupt() {
    if (_flight.isAnimating) _flight.stop();
  }

  /// Grouped per half zoom step, so panning never regroups and pins don't
  /// swap places mid-pinch.
  List<List<PlaceMapSurfaceMarker>> _groupsFor(MapCamera camera) {
    final step = (camera.zoom * 2).floorToDouble() / 2;
    if (step == _groupedZoom) return _groups;
    _groupedZoom = step;

    final fixed = <List<PlaceMapSurfaceMarker>>[];
    final clusterable = <PlaceMapSurfaceMarker>[];
    for (final marker in widget.markers) {
      if (marker.clusterPriority == null || step >= _declutterBelow) {
        fixed.add([marker]);
      } else {
        clusterable.add(marker);
      }
    }
    final ordered = clusterable.indexed.toList()
      ..sort((a, b) {
        final byPriority = b.$2.clusterPriority!.compareTo(
          a.$2.clusterPriority!,
        );
        return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
      });
    final grouped = clusterByProximity(
      ordered.map((item) => item.$2),
      spacing: _markerSpacing,
      position: (marker) => camera.crs.latLngToOffset(
        LatLng(marker.coordinate.latitude, marker.coordinate.longitude),
        step,
      ),
    );
    // Painted in order: plain, then the user's own, then selection on top.
    return _groups = [...grouped.reversed, ...fixed];
  }

  Marker _markerFor(List<PlaceMapSurfaceMarker> group) {
    final anchor = group.first;
    final clustered = group.length > 1;
    return Marker(
      key: anchor.id == null
          ? null
          : ValueKey('${clustered ? 'cluster' : 'pin'}-${anchor.id}'),
      point: LatLng(anchor.coordinate.latitude, anchor.coordinate.longitude),
      width: anchor.width,
      height: anchor.height,
      alignment: anchor.alignment,
      child: clustered
          ? PlaceClusterMarker(
              count: group.length,
              // The anchor has the highest priority in its group, so its
              // state is the one worth showing.
              ownVariant: anchor.clusterPriority! > 0
                  ? PlaceMarkerVariant.values[PlaceMarkerVariant
                            .standard
                            .index -
                        anchor.clusterPriority!]
                  : null,
              onPressed: () => _fit([
                for (final member in group) member.coordinate,
              ], maxZoom: _maxZoom),
            )
          : anchor.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: AppStrings.mapSemantic,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: LatLng(
                  widget.initialCoordinate.latitude,
                  widget.initialCoordinate.longitude,
                ),
                initialZoom: widget.initialZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                backgroundColor: dark
                    ? const Color(0xFFBEBDB9)
                    : const Color(0xFFEDECE8),
                onMapReady: _onReady,
                onPointerDown: (_, _) => _interrupt(),
                onTap: widget.onMapTap == null
                    ? null
                    : (_, coordinate) => widget.onMapTap!(
                        GeoPoint(coordinate.latitude, coordinate.longitude),
                      ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: <Widget>[
                // A quiet basemap: the pins are the only saturated thing on it.
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(
                    _mutedTiles(brightness: dark ? 0.82 : 1),
                  ),
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gelatino.app',
                  ),
                ),
                if (widget.markers.isNotEmpty)
                  Builder(
                    builder: (context) => MarkerLayer(
                      markers: _groupsFor(
                        MapCamera.of(context),
                      ).map(_markerFor).toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Positioned(left: 0, top: 0, child: _MapAttribution()),
      ],
    );
  }
}

List<double> _mutedTiles({required double brightness}) {
  const saturation = 0.45;
  const red = 0.2126 * (1 - saturation);
  const green = 0.7152 * (1 - saturation);
  const blue = 0.0722 * (1 - saturation);
  final b = brightness;
  return <double>[
    (red + saturation) * b, green * b, blue * b, 0, 0, //
    red * b, (green + saturation) * b, blue * b, 0, 0, //
    red * b, green * b, (blue + saturation) * b, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// Required by the OpenStreetMap tile licence.
final class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  static final Uri _copyright = Uri.https(
    'www.openstreetmap.org',
    '/copyright',
  );

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () =>
            launchUrl(_copyright, mode: LaunchMode.externalApplication),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppLayout.touchTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.fiorDiPanna,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  AppStrings.mapAttribution,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: AppColors.fondente,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
