import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';
import 'package:gelatino/utils/search_text.dart';

void main() {
  test('accents, case and punctuation do not matter', () {
    expect(normalizeSearchText("  Caffè dell'ORSO! "), 'caffe dell orso');
    expect(normalizeSearchText('Al 7º gusto'), 'al 7o gusto');
  });

  List<String> search(String query) => filterDiscoveryPlaces(
    [
      for (final (id, name, address) in [
        ('address', 'Neve', 'Via della Roma 1'),
        ('inside', 'Aroma', 'Via Po 2'),
        ('word', 'Gelato Roma', 'Via Po 3'),
        ('prefix', 'Romana', 'Via Po 4'),
        ('exact', 'Romà', 'Via Po 5'),
        ('other', 'Fiordilatte', 'Via Po 6'),
      ])
        DiscoveryPlace(
          place: Place(
            id: id,
            name: name,
            address: address,
            location: const GeoPoint(41.9, 12.5),
            geohash: 'sr2y',
            createdAt: DateTime(2026),
          ),
        ),
    ],
    query: query,
    filter: PlacesFilter.all,
    currentUid: null,
  ).map((entry) => entry.place.id).toList();

  test('results run from exact name down to address-only', () {
    expect(search('roma'), ['exact', 'prefix', 'word', 'inside', 'address']);
  });

  test('words match in any order across name and address', () {
    expect(search('po gelato'), ['word']);
  });

  test('a query of only punctuation matches nothing', () {
    expect(search('!!'), isEmpty);
  });
}
