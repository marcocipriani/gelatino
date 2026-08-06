import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/widgets/places/place_map_surface.dart';
import 'package:gelatino/widgets/places/place_marker.dart';

void main() {
  test('markers hang above their coordinate by default', () {
    // The Melt Pin tip is at the bottom edge, so the widget must sit above the
    // point. flutter_map's own default is Alignment.center, which drew every
    // gelateria half a marker south of where it actually is.
    const marker = PlaceMapSurfaceMarker(
      coordinate: GeoPoint(45, 9),
      child: SizedBox.shrink(),
    );
    expect(marker.alignment, Alignment.topCenter);

    // Symmetric markers opt out; the location dot has no tip to anchor.
    const dot = PlaceMapSurfaceMarker(
      coordinate: GeoPoint(45, 9),
      child: SizedBox.shrink(),
      alignment: Alignment.center,
    );
    expect(dot.alignment, Alignment.center);
  });

  test('pin box keeps the artwork ratio and clears the touch target', () {
    expect(PlaceMarker.pinWidth, greaterThanOrEqualTo(AppLayout.touchTarget));
    // Artwork is 320x448; the box must be taller than wide or the pin squashes.
    expect(PlaceMarker.pinHeight, greaterThan(PlaceMarker.pinWidth));
    // The box is sized for the selected pin so the hit area never shifts and
    // the enlarged pin is not clipped by the marker layer.
    expect(PlaceMarker.boxWidth, PlaceMarker.pinWidth * PlaceMarker.selectedScale);
    expect(
      PlaceMarker.boxHeight,
      PlaceMarker.pinHeight * PlaceMarker.selectedScale,
    );
  });

  test('an unattached controller drops moves instead of throwing', () {
    final controller = PlaceMapSurfaceController();
    expect(controller.isAttached, isFalse);
    expect(() => controller.moveTo(const GeoPoint(45, 9)), returnsNormally);

    GeoPoint? moved;
    double? zoom;
    controller.attach((coordinate, value) {
      moved = coordinate;
      zoom = value;
    });
    expect(controller.isAttached, isTrue);
    controller.moveTo(const GeoPoint(45, 9), zoom: 16);
    expect(moved, const GeoPoint(45, 9));
    expect(zoom, 16);

    controller.detach();
    expect(controller.isAttached, isFalse);
  });
}
