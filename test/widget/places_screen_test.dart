import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/location_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/screens/places_tab.dart';
import 'package:gelatino/widgets/places/add_place_dialog.dart';
import 'package:gelatino/widgets/places/place_map_surface.dart';
import 'package:gelatino/widgets/places/place_marker.dart';

void main() {
  for (final viewport in <({Size size, String layout})>[
    (size: const Size(390, 844), layout: 'compact'),
    (size: const Size(768, 1024), layout: 'medium'),
    (size: const Size(1024, 900), layout: 'wide'),
    (size: const Size(1440, 1000), layout: 'wide'),
  ]) {
    testWidgets(
      '${viewport.size.width.toInt()} renders ${viewport.layout} Places without overflow',
      (tester) async {
        await _pumpPlaces(tester, size: viewport.size);

        expect(
          find.byKey(ValueKey<String>('places-${viewport.layout}-layout')),
          findsOneWidget,
        );
        if (viewport.layout == 'wide') {
          expect(
            find.byKey(const ValueKey('places-view-toggle')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('places-list-pane')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('places-map-pane')), findsOneWidget);
          final listWidth = tester
              .getSize(find.byKey(const ValueKey('places-list-pane')))
              .width;
          final mapWidth = tester
              .getSize(find.byKey(const ValueKey('places-map-pane')))
              .width;
          expect(listWidth, inInclusiveRange(400, 520));
          expect(mapWidth, greaterThan(listWidth));
        } else {
          expect(
            find.byKey(const ValueKey('places-view-toggle')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('places-list-pane')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('places-map-pane')), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('compact toggle preserves search filter and selection', (
    tester,
  ) async {
    await _pumpPlaces(tester, size: const Size(390, 844));

    await tester.enterText(
      find.byKey(const ValueKey('places-search-field')),
      'Aurora',
    );
    await tester.drag(
      find.byKey(const ValueKey('places-filter-scroll')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-saved')));
    await tester.tap(find.byKey(const ValueKey('place-row-a')));
    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('places-list-pane')), findsNothing);
    expect(find.byKey(const ValueKey('places-map-pane')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('places-search-field')))
          .controller
          ?.text,
      'Aurora',
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('filter-saved')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('place-marker-a')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('explicit view wins when account default arrives later', (
    tester,
  ) async {
    await _pumpPlaces(tester, size: const Size(390, 844));

    await tester.tap(find.text('Mappa'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlacesTab)),
    );
    container.read(_delayedDefaultProvider.notifier).emit('list');
    await tester.pump();

    expect(find.byKey(const ValueKey('places-map-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('places-list-pane')), findsNothing);
  });

  testWidgets('synchronous account default applies outside widget mount', (
    tester,
  ) async {
    await _pumpPlaces(
      tester,
      size: const Size(390, 844),
      initialDefaultView: 'map',
    );

    expect(find.byKey(const ValueKey('places-map-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('places-list-pane')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows exact five 44px filters with selected semantics', (
    tester,
  ) async {
    await _pumpPlaces(tester);

    for (final label in <String>[
      'Tutte',
      'Mi piace',
      'Preferite',
      'Salvate',
      'Aggiunte da me',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final filter in PlacesFilter.values) {
      final finder = find.byKey(ValueKey<String>('filter-${filter.name}'));
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
      expect(tester.getSemantics(finder).flagsCollection.isButton, isTrue);
    }
  });

  testWidgets('wide row and marker share selection in both directions', (
    tester,
  ) async {
    await _pumpPlaces(tester, size: const Size(1440, 1000));

    expect(find.byType(PlaceMarker), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('place-row-a')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('place-marker-a')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('place-marker-b')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('place-row-b')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('marker variants use distinct icons and truthful semantics', (
    tester,
  ) async {
    await _pumpPlaces(
      tester,
      size: const Size(1440, 1000),
      entries: <DiscoveryPlace>[
        DiscoveryPlace(place: _place('favorite'), favorite: true),
        DiscoveryPlace(place: _place('saved'), saved: true),
        DiscoveryPlace(place: _place('liked'), liked: true),
        DiscoveryPlace(place: _place('mine', addedByUid: 'alice')),
        DiscoveryPlace(place: _place('standard')),
      ],
    );

    for (final variant in PlaceMarkerVariant.values) {
      expect(
        find.byKey(ValueKey<String>('marker-icon-${variant.name}')),
        findsOneWidget,
      );
    }
    final marker = find.byKey(const ValueKey('place-marker-favorite'));
    expect(tester.getSize(marker).width, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(marker).label, contains('preferita'));
    expect(
      tester.getSemantics(marker).flagsCollection.isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('loading error no-match and auth states have recovery', (
    tester,
  ) async {
    await _pumpPlaces(
      tester,
      discovery: const AsyncLoading<List<DiscoveryPlace>>(),
    );
    expect(
      find.byKey(const ValueKey('places-loading-skeleton')),
      findsOneWidget,
    );

    await _pumpPlaces(
      tester,
      size: const Size(1024, 900),
      discovery: const AsyncLoading<List<DiscoveryPlace>>(),
    );
    final loadingList = find.byKey(const ValueKey('places-loading-list-pane'));
    final loadingMap = find.byKey(const ValueKey('places-loading-map-pane'));
    expect(tester.getSize(loadingList).width, inInclusiveRange(400, 520));
    expect(
      tester.getSize(loadingMap).width,
      greaterThan(tester.getSize(loadingList).width),
    );

    await _pumpPlaces(
      tester,
      discovery: AsyncError<List<DiscoveryPlace>>(
        StateError('offline'),
        StackTrace.empty,
      ),
    );
    expect(find.text('Riprova'), findsOneWidget);

    await _pumpPlaces(tester, authenticated: false);
    await tester.drag(
      find.byKey(const ValueKey('places-filter-scroll')),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-saved')));
    await tester.pump();
    expect(find.text('Accedi per usare i filtri personali.'), findsOneWidget);
  });

  testWidgets('empty catalog and filtered-empty expose useful actions', (
    tester,
  ) async {
    await _pumpPlaces(tester, entries: const <DiscoveryPlace>[]);
    expect(find.text('Aggiungi gelateria'), findsOneWidget);
    expect(find.text('Azzera filtri'), findsNothing);

    await _pumpPlaces(
      tester,
      entries: const <DiscoveryPlace>[],
      authenticated: false,
    );
    expect(find.text('Accedi'), findsOneWidget);
    expect(find.text('Azzera filtri'), findsNothing);

    await _pumpPlaces(tester);
    await tester.enterText(
      find.byKey(const ValueKey('places-search-field')),
      'nessun risultato',
    );
    await tester.pump();
    expect(find.text('Azzera filtri'), findsOneWidget);
  });

  testWidgets(
    'GPS failure offers retry and explicit map point used by createPlace',
    (tester) async {
      final repository = _RecordingPlaceRepository();
      final service = DeviceLocationService(
        _TestLocationGateway(
          failure: const LocationFailure('GPS non disponibile.'),
        ),
      );
      await _pumpPlaces(
        tester,
        locationService: service,
        repository: repository,
        mapTapCoordinate: const GeoPoint(46.12345, 10.54321),
      );

      await tester.tap(find.byKey(const ValueKey('add-place-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nome'),
        'Nuova Gelateria',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Indirizzo'),
        'Via Test 1',
      );
      await tester.tap(find.text('Usa la posizione'));
      await tester.pumpAndSettle();

      expect(find.text('Riprova posizione'), findsOneWidget);
      expect(find.text('Scegli sulla mappa'), findsOneWidget);

      await tester.tap(find.text('Scegli sulla mappa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('place-location-picker-map')));
      await tester.pump();
      await tester.tap(find.text('Conferma punto'));
      await tester.pumpAndSettle();

      expect(repository.creates, hasLength(1));
      expect(repository.creates.single.$1, 'Nuova Gelateria');
      expect(repository.creates.single.$2, 'Via Test 1');
      expect(repository.creates.single.$3.latitude, closeTo(46.12345, 0.0001));
      expect(repository.creates.single.$3.longitude, closeTo(10.54321, 0.0001));
    },
  );

  testWidgets(
    'add dialog cannot dismiss during GPS or create and submits once',
    (tester) async {
      final locationPending = Completer<DeviceLocation>();
      final createPending = Completer<Place>();
      final repository = _RecordingPlaceRepository()
        ..createPending = createPending;
      await _pumpPlaces(
        tester,
        locationService: DeviceLocationService(
          _TestLocationGateway(pending: locationPending),
        ),
        repository: repository,
      );

      await tester.tap(find.byKey(const ValueKey('add-place-action')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Neve');
      await tester.enterText(
        find.widgetWithText(TextField, 'Indirizzo'),
        'Via Fredda 2',
      );
      await tester.tap(find.text('Usa la posizione'));
      await tester.pump();

      await _attemptDialogDismissal(tester);
      expect(find.byType(AddPlaceDialog), findsOneWidget);
      expect(find.text('Neve'), findsOneWidget);
      expect(repository.creates, isEmpty);
      expect(tester.takeException(), isNull);

      locationPending.complete(
        const DeviceLocation(latitude: 45.7, longitude: 9.4),
      );
      await tester.pump();
      await tester.pump();
      expect(repository.creates, hasLength(1));

      await _attemptDialogDismissal(tester);
      expect(find.byType(AddPlaceDialog), findsOneWidget);
      expect(repository.creates, hasLength(1));
      expect(tester.takeException(), isNull);

      createPending.complete(_place('created'));
      await tester.pumpAndSettle();
      expect(find.byType(AddPlaceDialog), findsNothing);
      expect(repository.creates, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _attemptDialogDismissal(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pump();
  await tester.binding.handlePopRoute();
  await tester.pump();
  final cancel = tester.widget<TextButton>(
    find.widgetWithText(TextButton, 'Annulla'),
  );
  expect(cancel.onPressed, isNull);
}

Future<void> _pumpPlaces(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<DiscoveryPlace>? entries,
  AsyncValue<List<DiscoveryPlace>>? discovery,
  bool authenticated = true,
  DeviceLocationService? locationService,
  PlaceRepository? repository,
  GeoPoint mapTapCoordinate = const GeoPoint(46, 10),
  String? initialDefaultView,
}) async {
  final catalog =
      entries ??
      <DiscoveryPlace>[
        DiscoveryPlace(
          place: _place('a', name: 'Aurora'),
          liked: true,
          favorite: true,
          saved: true,
        ),
        DiscoveryPlace(place: _place('b', name: 'Fiordilatte')),
      ];
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUidProvider.overrideWithValue(authenticated ? 'alice' : null),
        if (initialDefaultView == null)
          defaultCollectionViewProvider.overrideWith(
            (ref) => ref.watch(_delayedDefaultProvider),
          )
        else
          defaultCollectionViewProvider.overrideWithValue(initialDefaultView),
        placeMapSurfaceAdapterProvider.overrideWithValue(
          _TestMapSurfaceAdapter(tapCoordinate: mapTapCoordinate),
        ),
        if (locationService != null)
          deviceLocationServiceProvider.overrideWithValue(locationService),
        if (repository != null)
          placeRepositoryProvider.overrideWithValue(repository),
        placesDiscoveryDataProvider.overrideWith((ref) {
          if (discovery != null) return discovery;
          final state = ref.watch(placesDiscoveryControllerProvider);
          return AsyncData<List<DiscoveryPlace>>(
            filterDiscoveryPlaces(
              catalog,
              query: state.query,
              filter: state.filter,
              currentUid: authenticated ? 'alice' : null,
            ),
          );
        }),
      ],
      child: const MaterialApp(home: PlacesTab()),
    ),
  );
  await tester.pumpAndSettle();
}

final _delayedDefaultProvider = NotifierProvider<_DelayedDefault, String?>(
  _DelayedDefault.new,
);

final class _DelayedDefault extends Notifier<String?> {
  @override
  String? build() => null;

  void emit(String? value) => state = value;
}

Place _place(String id, {String? name, String? addedByUid}) => Place(
  id: id,
  name: name ?? 'Gelateria $id',
  address: 'Via $id 1',
  location: GeoPoint(45.46 + id.codeUnitAt(0) / 10000, 9.18),
  geohash: 'u0nd9',
  createdAt: DateTime(2026, 7, 15),
  addedByUid: addedByUid,
);

final class _TestLocationGateway implements LocationGateway {
  const _TestLocationGateway({this.failure, this.pending});

  final Object? failure;
  final Completer<DeviceLocation>? pending;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    if (failure case final error?) throw error;
    if (pending case final completion?) return completion.future;
    return const DeviceLocation(latitude: 45, longitude: 9);
  }
}

final class _RecordingPlaceRepository implements PlaceRepository {
  final List<(String, String, GeoPoint)> creates =
      <(String, String, GeoPoint)>[];
  Completer<Place>? createPending;

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    creates.add((name, address, location));
    final created = Place(
      id: 'created',
      name: name,
      address: address,
      location: location,
      geohash: 'u0nd9',
      createdAt: DateTime(2026, 7, 15),
      addedByUid: 'alice',
    );
    if (createPending case final pending?) return pending.future;
    return created;
  }

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) => throw UnimplementedError();

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) async => const [];

  @override
  Stream<List<Place>> watchPlaces() => const Stream.empty();
}

final class _TestMapSurfaceAdapter implements PlaceMapSurfaceAdapter {
  const _TestMapSurfaceAdapter({required this.tapCoordinate});

  final GeoPoint tapCoordinate;

  @override
  Widget buildSurface(
    BuildContext context, {
    required GeoPoint initialCoordinate,
    required double initialZoom,
    required List<PlaceMapSurfaceMarker> markers,
    required ValueChanged<GeoPoint>? onMapTap,
    PlaceMapSurfaceController? controller,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onMapTap == null ? null : () => onMapTap(tapCoordinate),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: markers.map((marker) => marker.child).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
