import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design/app_tokens.dart';
import 'place_map_surface.dart';
import 'place_marker.dart';

final class PlaceLocationPicker extends ConsumerWidget {
  const PlaceLocationPicker({
    required this.initialCoordinate,
    required this.selectedCoordinate,
    required this.onSelected,
    super.key,
  });

  final GeoPoint initialCoordinate;
  final GeoPoint? selectedCoordinate;
  final ValueChanged<GeoPoint> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marker = selectedCoordinate;
    return SizedBox(
      key: const ValueKey<String>('place-location-picker-map'),
      height: 260,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: ref
            .watch(placeMapSurfaceAdapterProvider)
            .buildSurface(
              context,
              initialCoordinate: initialCoordinate,
              initialZoom:
                  initialCoordinate.latitude == 0 &&
                      initialCoordinate.longitude == 0
                  ? 2
                  : 13,
              markers: marker == null
                  ? const <PlaceMapSurfaceMarker>[]
                  : <PlaceMapSurfaceMarker>[
                      PlaceMapSurfaceMarker(
                        coordinate: marker,
                        width: PlaceMarker.pinWidth,
                        height: PlaceMarker.pinHeight,
                        child: SvgPicture.asset(
                          'assets/images/pin-fondente.svg',
                          height: PlaceMarker.pinHeight,
                          colorFilter: const ColorFilter.mode(
                            AppColors.fragola,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
              onMapTap: onSelected,
            ),
      ),
    );
  }
}
