import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/screens/places_tab.dart';
import 'package:gelatino/widgets/places/place_map_surface.dart';

void main() {
  testWidgets(
    'wide list and map share one aggregate provider element and identical data',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var aggregateBuilds = 0;
      var perPlaceBuilds = 0;
      final observer = _DiscoveryObserver();
      final entries = <DiscoveryPlace>[
        DiscoveryPlace(place: _place('a')),
        DiscoveryPlace(place: _place('b')),
      ];

      await tester.pumpWidget(
        ProviderScope(
          observers: <ProviderObserver>[observer],
          overrides: [
            currentUidProvider.overrideWithValue('alice'),
            defaultCollectionViewProvider.overrideWithValue(null),
            placeMapSurfaceAdapterProvider.overrideWithValue(
              const _MarkerSurfaceAdapter(),
            ),
            placesDiscoveryDataProvider.overrideWith((ref) {
              aggregateBuilds++;
              return AsyncData<List<DiscoveryPlace>>(entries);
            }),
            placeStateProvider.overrideWith((ref, _) {
              perPlaceBuilds++;
              return const AsyncData<PlaceState?>(null);
            }),
          ],
          child: const MaterialApp(home: PlacesTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(observer.aggregateElementsAdded, 1);
      expect(aggregateBuilds, 1);
      expect(perPlaceBuilds, 0);
      for (final id in <String>['a', 'b']) {
        expect(find.byKey(ValueKey<String>('place-row-$id')), findsOneWidget);
        expect(
          find.byKey(ValueKey<String>('place-marker-$id')),
          findsOneWidget,
        );
      }
    },
  );

  test('Places boundary has no per-place provider fan-out', () {
    final screen = File('lib/screens/places_tab.dart').readAsStringSync();
    final list = File('lib/widgets/places/place_list.dart').readAsStringSync();
    final map = File('lib/widgets/places/place_map.dart').readAsStringSync();
    final combined = '$screen\n$list\n$map';

    expect(screen, contains('ref.watch(placesDiscoveryDataProvider)'));
    expect(combined, isNot(contains('placeStateProvider(')));
    expect(combined, isNot(contains('ref.watch(placesProvider)')));
  });
}

final class _DiscoveryObserver extends ProviderObserver {
  int aggregateElementsAdded = 0;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    if (context.provider.name == 'placesDiscoveryDataProvider') {
      aggregateElementsAdded++;
    }
  }
}

final class _MarkerSurfaceAdapter implements PlaceMapSurfaceAdapter {
  const _MarkerSurfaceAdapter();

  @override
  Widget buildSurface(
    BuildContext context, {
    required GeoPoint initialCoordinate,
    required double initialZoom,
    required List<PlaceMapSurfaceMarker> markers,
    required ValueChanged<GeoPoint>? onMapTap,
    PlaceMapSurfaceController? controller,
  }) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Wrap(
      children: markers.map((marker) => marker.child).toList(growable: false),
    ),
  );
}

Place _place(String id) => Place(
  id: id,
  name: 'Gelateria $id',
  address: 'Via $id',
  location: const GeoPoint(45, 9),
  geohash: 'u0nd9',
  createdAt: DateTime(2026, 7, 15),
  addedByUid: 'alice',
);
