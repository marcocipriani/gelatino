import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../design/app_tokens.dart';

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
  });

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

  void attach(void Function(GeoPoint coordinate, double zoom) move) {
    _move = move;
  }

  void detach() {
    _move = null;
  }

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

final class _FlutterMapSurfaceState extends State<_FlutterMapSurface> {
  final MapController _map = MapController();

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(_move);
  }

  @override
  void didUpdateWidget(covariant _FlutterMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_move);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _map.dispose();
    super.dispose();
  }

  void _move(GeoPoint coordinate, double zoom) =>
      _map.move(LatLng(coordinate.latitude, coordinate.longitude), zoom);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: LatLng(
          widget.initialCoordinate.latitude,
          widget.initialCoordinate.longitude,
        ),
        initialZoom: widget.initialZoom,
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
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gelatino.app',
        ),
        if (widget.markers.isNotEmpty)
          MarkerLayer(
            markers: widget.markers
                .map(
                  (marker) => Marker(
                    point: LatLng(
                      marker.coordinate.latitude,
                      marker.coordinate.longitude,
                    ),
                    width: marker.width,
                    height: marker.height,
                    alignment: marker.alignment,
                    child: marker.child,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}
