import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';

void main() {
  group('PlacesDiscoveryController', () {
    test(
      'loaded default applies once but never replaces an explicit choice',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          placesDiscoveryControllerProvider.notifier,
        );

        controller.chooseView(PlacesViewMode.map);
        controller.applyLoadedDefault('list');
        expect(
          container.read(placesDiscoveryControllerProvider),
          const PlacesDiscoveryState(
            viewMode: PlacesViewMode.map,
            userExplicitlyChoseView: true,
          ),
        );
      },
    );

    test('identity change resets interaction and permits the new default', () {
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWith((ref) => ref.watch(_testUidProvider)),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        placesDiscoveryControllerProvider.notifier,
      );

      controller.applyLoadedDefault('map');
      controller.setQuery('Aurora');
      controller.chooseView(PlacesViewMode.list);
      container.read(_testUidProvider.notifier).emit('bob');

      final reset = container.read(placesDiscoveryControllerProvider);
      expect(reset, const PlacesDiscoveryState());
      container
          .read(placesDiscoveryControllerProvider.notifier)
          .applyLoadedDefault('map');
      expect(
        container.read(placesDiscoveryControllerProvider).viewMode,
        PlacesViewMode.map,
      );
    });

    test('query filter and selection survive view changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        placesDiscoveryControllerProvider.notifier,
      );

      controller.setQuery('Aurora');
      controller.setFilter(PlacesFilter.saved);
      controller.selectPlace('place-2');
      controller.chooseView(PlacesViewMode.map);

      final state = container.read(placesDiscoveryControllerProvider);
      expect(state.query, 'Aurora');
      expect(state.filter, PlacesFilter.saved);
      expect(state.selectedPlaceId, 'place-2');
      expect(state.viewMode, PlacesViewMode.map);
    });
  });

  test('query and filters preserve catalog order', () {
    final places = <DiscoveryPlace>[
      DiscoveryPlace(place: _place('b', 'Fiordilatte', 'Via Menta 2')),
      DiscoveryPlace(
        place: _place('a', 'Aurora', 'Piazza Fragola 1'),
        liked: true,
        favorite: true,
        saved: true,
      ),
      DiscoveryPlace(
        place: _place('c', 'Sorbetto', 'Via Aurora 3', addedByUid: 'alice'),
      ),
    ];

    expect(
      filterDiscoveryPlaces(
        places,
        query: 'AURORA',
        filter: PlacesFilter.all,
        currentUid: 'alice',
      ).map((entry) => entry.place.id),
      <String>['a', 'c'],
    );
    expect(
      filterDiscoveryPlaces(
        places,
        query: '',
        filter: PlacesFilter.liked,
        currentUid: 'alice',
      ).map((entry) => entry.place.id),
      <String>['a'],
    );
    expect(
      filterDiscoveryPlaces(
        places,
        query: '',
        filter: PlacesFilter.favorites,
        currentUid: 'alice',
      ).map((entry) => entry.place.id),
      <String>['a'],
    );
    expect(
      filterDiscoveryPlaces(
        places,
        query: '',
        filter: PlacesFilter.saved,
        currentUid: 'alice',
      ).map((entry) => entry.place.id),
      <String>['a'],
    );
    expect(
      filterDiscoveryPlaces(
        places,
        query: '',
        filter: PlacesFilter.addedByMe,
        currentUid: 'alice',
      ).map((entry) => entry.place.id),
      <String>['c'],
    );
  });

  test(
    'aggregated provider joins private flags once in catalog order',
    () async {
      final catalog = <Place>[
        _place('b', 'Fiordilatte', 'Via Menta 2'),
        _place('a', 'Aurora', 'Piazza Fragola 1'),
      ];
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placesProvider.overrideWith((ref) => Stream.value(catalog)),
          likedPlacesProvider.overrideWithValue(
            AsyncData<List<Place>>(<Place>[catalog.first]),
          ),
          favoritePlacesProvider.overrideWithValue(
            AsyncData<List<Place>>(<Place>[catalog.last]),
          ),
          savedPlacesProvider.overrideWithValue(
            AsyncData<List<Place>>(<Place>[catalog.first]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        placesDiscoveryDataProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.pump();
      await container.pump();
      final result = container.read(placesDiscoveryDataProvider).requireValue;

      expect(result.map((entry) => entry.place.id), <String>['b', 'a']);
      expect(result.first.liked, isTrue);
      expect(result.first.saved, isTrue);
      expect(result.last.favorite, isTrue);
    },
  );

  test(
    'marker precedence covers favorite saved liked user-added and default',
    () {
      expect(
        markerVariantFor(
          const DiscoveryPlace(
            place: _placeholder,
            liked: true,
            favorite: true,
            saved: true,
          ),
          currentUid: 'alice',
        ),
        PlaceMarkerVariant.favorite,
      );
      expect(
        markerVariantFor(
          const DiscoveryPlace(place: _placeholder, liked: true, saved: true),
          currentUid: 'alice',
        ),
        PlaceMarkerVariant.saved,
      );
      expect(
        markerVariantFor(
          const DiscoveryPlace(place: _placeholder, liked: true),
          currentUid: 'alice',
        ),
        PlaceMarkerVariant.liked,
      );
      expect(
        markerVariantFor(
          DiscoveryPlace(
            place: _place('mine', 'Mia', 'Qui', addedByUid: 'alice'),
          ),
          currentUid: 'alice',
        ),
        PlaceMarkerVariant.userAdded,
      );
      expect(
        markerVariantFor(
          const DiscoveryPlace(place: _placeholder),
          currentUid: 'alice',
        ),
        PlaceMarkerVariant.standard,
      );
    },
  );

  test('optimistic overlay changes only fields that are actually pending', () {
    final place = _place('a', 'Aurora', 'Piazza Fragola 1');
    final result = aggregateDiscoveryPlaces(
      catalog: <Place>[place],
      liked: <Place>[place],
      favorites: <Place>[place],
      saved: <Place>[place],
      optimistic: PlaceStateControllerSnapshot(
        states: <String, PlaceState>{place.id: PlaceState.empty(place.id)},
        pendingKeys: <PlaceStateOperationKey>{
          (placeId: place.id, field: PlaceStateField.saved),
        },
      ),
    ).single;

    expect(result.liked, isTrue);
    expect(result.favorite, isTrue);
    expect(result.saved, isFalse);
  });

  test(
    'discovery boundary has no per-place state provider or Rome fallback',
    () {
      final source = File(
        'lib/providers/places_discovery_provider.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('placeStateProvider(')));
      expect(source, isNot(contains('41.9028')));
      expect(source.toLowerCase(), isNot(contains('rome')));
      expect(source.toLowerCase(), isNot(contains('roma')));
    },
  );
}

final _testUidProvider = NotifierProvider<_TestUid, String?>(_TestUid.new);

final class _TestUid extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void emit(String? uid) => state = uid;
}

const _placeholder = Place(
  id: 'place',
  name: 'Gelateria',
  address: 'Indirizzo',
  location: GeoPoint(0, 0),
  geohash: 's0000',
  createdAt: _createdAt,
);

const _createdAt = _ConstDateTime();

final class _ConstDateTime implements DateTime {
  const _ConstDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Place _place(String id, String name, String address, {String? addedByUid}) =>
    Place(
      id: id,
      name: name,
      address: address,
      location: const GeoPoint(45, 9),
      geohash: 'u0nd9',
      createdAt: DateTime(2026, 7, 15),
      addedByUid: addedByUid,
    );
