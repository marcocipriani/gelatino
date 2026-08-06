import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/flavor_search_provider.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';

void main() {
  test(
    'flavor matches join name matches without duplicates, sorted by rating',
    () {
      final entries = [
        discoveryPlace('p1', name: 'Gelateria Pistone'), // match per nome
        discoveryPlace('p2', name: 'Da Mario'),
        discoveryPlace('p3', name: 'Cremeria Zero'),
      ];
      final filtered = filterDiscoveryPlaces(
        entries,
        query: 'pist',
        filter: PlacesFilter.all,
        currentUid: 'me',
        flavorMatches: {
          'p2': const FlavorPlaceMatch(
            flavorName: 'Pistacchio',
            colorHex: null,
            bestRating: 5,
            tastings: 2,
          ),
          'p3': const FlavorPlaceMatch(
            flavorName: 'Pistacchio',
            colorHex: null,
            bestRating: 3,
            tastings: 1,
          ),
        },
      );
      expect(filtered.map((e) => e.place.id).toList(), ['p2', 'p3', 'p1']);
      expect(filtered[0].flavorMatch, isNotNull);
      expect(filtered[2].flavorMatch, isNull);
    },
  );

  test('a place matched by both name and flavor appears once, as a flavor match', () {
    final entries = [
      discoveryPlace('p1', name: 'Gelateria Pistone'),
      discoveryPlace('p2', name: 'Da Mario'),
    ];
    final filtered = filterDiscoveryPlaces(
      entries,
      query: 'pist',
      filter: PlacesFilter.all,
      currentUid: 'me',
      flavorMatches: {
        'p1': const FlavorPlaceMatch(
          flavorName: 'Pistacchio',
          colorHex: '#8BC34A',
          bestRating: 4,
          tastings: 1,
        ),
      },
    );

    expect(filtered.length, 1);
    expect(filtered.single.place.id, 'p1');
    expect(filtered.single.flavorMatch?.flavorName, 'Pistacchio');
  });

  test('without flavorMatches, filtering behaves exactly as before', () {
    final entries = [
      discoveryPlace('p1', name: 'Gelateria Pistone'),
      discoveryPlace('p2', name: 'Da Mario'),
    ];
    final filtered = filterDiscoveryPlaces(
      entries,
      query: 'pist',
      filter: PlacesFilter.all,
      currentUid: 'me',
    );

    expect(filtered.map((e) => e.place.id).toList(), ['p1']);
    expect(filtered.single.flavorMatch, isNull);
  });
}

DiscoveryPlace discoveryPlace(String id, {required String name}) =>
    DiscoveryPlace(
      place: Place(
        id: id,
        name: name,
        address: 'Via Test 1',
        location: const GeoPoint(45, 9),
        geohash: 'u0nd9',
        createdAt: DateTime(2026, 7, 15),
      ),
    );
