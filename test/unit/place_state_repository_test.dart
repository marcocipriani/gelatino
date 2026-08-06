import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/repositories/place_state_repository.dart';

void main() {
  group('PlaceStateRepository', () {
    late RecordingPlaceStateDataSource source;
    late PlaceStateRepository repository;

    setUp(() {
      source = RecordingPlaceStateDataSource();
      repository = PlaceStateRepositoryImpl(source);
    });

    test('watches the exact private state document path', () async {
      source.document = PlaceStateDocument(
        id: 'gelateria-1',
        data: <String, dynamic>{'saved': true},
      );

      final state = await repository.watchState('alice', 'gelateria-1').first;

      expect(state?.placeId, 'gelateria-1');
      expect(state?.saved, isTrue);
      expect(source.watchedPaths, <String>[
        'users/alice/place_states/gelateria-1',
      ]);
      expect(source.queries, isEmpty);
    });

    test('uses the exact index-aligned saved favorite and liked queries', () {
      repository.watchSaved('alice');
      repository.watchFavorites('alice');
      repository.watchLiked('alice');

      expect(source.queries, hasLength(3));
      expectQuery(source.queries[0], field: 'saved', orderBy: 'saved_at');
      expectQuery(source.queries[1], field: 'favorite', orderBy: 'favorite_at');
      expectQuery(source.queries[2], field: 'liked', orderBy: null);
      expect(source.watchedPaths, isEmpty);
    });

    test(
      'query parsing preserves server order and skips malformed state',
      () async {
        final errors = captureFlutterErrors();
        source.queryDocuments = <PlaceStateDocument>[
          PlaceStateDocument(
            id: 'second',
            data: <String, dynamic>{'saved': true},
          ),
          PlaceStateDocument(id: 'broken', data: <String, dynamic>{'saved': 1}),
          PlaceStateDocument(
            id: 'first',
            data: <String, dynamic>{'saved': true},
          ),
        ];

        final states = await repository.watchSaved('alice').first;

        expect(states.map((state) => state.placeId), <String>[
          'second',
          'first',
        ]);
        expect(errors, hasLength(1));
        expect(
          errors.single.context.toString(),
          contains('place_states/broken'),
        );
      },
    );

    test(
      'invalid UID and place ID fail before every datasource access',
      () async {
        for (final invalid in <String>['', 'a/b', 'a\n', 'x' * 129]) {
          expect(
            () => repository.watchState(invalid, 'place-1'),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.watchState('alice', invalid),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.watchSaved(invalid),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.watchFavorites(invalid),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.watchLiked(invalid),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.setSaved(invalid, 'place-1', true),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.setFavorite('alice', invalid, true),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.setLiked('alice', invalid, true),
            throwsA(isA<FormatException>()),
          );
          expect(
            () => repository.setNote('alice', invalid, 'nota'),
            throwsA(isA<FormatException>()),
          );
        }

        expect(source.watchedPaths, isEmpty);
        expect(source.queries, isEmpty);
        expect(source.writes, isEmpty);
      },
    );

    test(
      'writes exact merge payloads for true and false state fields',
      () async {
        await repository.setSaved('alice', 'place-1', true);
        await repository.setSaved('alice', 'place-1', false);
        await repository.setFavorite('alice', 'place-1', true);
        await repository.setFavorite('alice', 'place-1', false);
        await repository.setLiked('alice', 'place-1', true);
        await repository.setLiked('alice', 'place-1', false);

        expect(source.writes, hasLength(6));
        expectToggleWrite(source.writes[0], 'saved', 'saved_at', true);
        expectToggleWrite(source.writes[1], 'saved', 'saved_at', false);
        expectToggleWrite(source.writes[2], 'favorite', 'favorite_at', true);
        expectToggleWrite(source.writes[3], 'favorite', 'favorite_at', false);
        expectToggleWrite(source.writes[4], 'liked', 'liked_at', true);
        expectToggleWrite(source.writes[5], 'liked', 'liked_at', false);
        expect(
          source.writes,
          everyElement(
            isA<RecordedStateWrite>().having(
              (write) => write.path,
              'path',
              'users/alice/place_states/place-1',
            ),
          ),
        );
      },
    );

    test(
      'note set and delete use merge without touching catalog fields',
      () async {
        await repository.setNote('alice', 'place-1', ' Tavolino fuori ');
        await repository.setNote('alice', 'place-1', null);

        expect(source.writes[0].data, <String, Object?>{
          'note': 'Tavolino fuori',
          'updated_at': const PlaceServerTimestamp(),
        });
        expect(source.writes[1].data, <String, Object?>{
          'note': const PlaceDelete(),
          'updated_at': const PlaceServerTimestamp(),
        });
        for (final write in source.writes) {
          expect(write.data, isNot(contains('liked_by_uids')));
          expect(write.data, isNot(contains('favorited_by_uids')));
          expect(write.data, isNot(contains('wishlisted_by_uids')));
          expect(write.path, isNot(startsWith('places/')));
        }
      },
    );
  });

  group('PlaceRepository', () {
    late RecordingPlaceDataSource source;
    late String? currentUid;
    late PlaceRepository repository;

    setUp(() {
      source = RecordingPlaceDataSource();
      currentUid = 'alice';
      repository = PlaceRepositoryImpl(source, () => currentUid);
    });

    test(
      'catalog reads all documents, reports malformed, and sorts name then ID',
      () async {
        final errors = captureFlutterErrors();
        source.catalogDocuments = <PlaceDocument>[
          placeDocument('z-place', name: 'B'),
          PlaceDocument(
            id: 'broken',
            data: <String, dynamic>{'address': 'Missing name'},
          ),
          placeDocument('b-place', name: 'A'),
          placeDocument('a-place', name: 'A'),
        ];

        final places = await repository.watchPlaces().first;

        expect(places.map((place) => place.id), <String>[
          'a-place',
          'b-place',
          'z-place',
        ]);
        expect(source.catalogQueries.single.collectionPath, 'places');
        expect(
          File('lib/repositories/place_repository.dart').readAsStringSync(),
          isNot(contains('.orderBy(')),
        );
        expect(errors, hasLength(1));
        expect(errors.single.context.toString(), contains('places/broken'));
      },
    );

    test(
      'exact reads deduplicate IDs and isolate missing malformed documents',
      () async {
        final errors = captureFlutterErrors();
        source.documents['places/a'] = placeDocument('a', name: 'A');
        source.documents['places/b'] = PlaceDocument(
          id: 'b',
          data: <String, dynamic>{'name': 'Broken'},
        );
        source.documents['places/c'] = placeDocument('c', name: 'C');

        final places = await repository.readPlaces(<String>[
          'c',
          'missing',
          'b',
          'c',
          'a',
        ]);

        expect(source.readPaths, <String>[
          'places/c',
          'places/missing',
          'places/b',
          'places/a',
        ]);
        expect(places.map((place) => place.id), <String>['c', 'a']);
        expect(errors, hasLength(1));
        expect(errors.single.context.toString(), contains('places/b'));
      },
    );

    test('an unavailable exact catalog read remains a hard failure', () async {
      source.documents['places/a'] = placeDocument('a');
      source.readErrors['places/b'] = StateError('unavailable');

      await expectLater(
        repository.readPlaces(<String>['a', 'b']),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'unavailable',
          ),
        ),
      );
      expect(source.readPaths, <String>['places/a', 'places/b']);
    });

    test(
      'createPlace writes exact allowlist and deterministic geohash',
      () async {
        const location = GeoPoint(45.4642, 9.19);
        source.createdResult = placeDocument(
          'new-place',
          name: 'Gelateria Milano',
          address: 'Via Torino 1',
          location: location,
          geohash: GeoFirePoint(location).geohash,
        );

        final place = await repository.createPlace(
          name: ' Gelateria Milano ',
          address: ' Via Torino 1 ',
          location: location,
        );

        expect(place.id, 'new-place');
        expect(source.createdCollectionPaths, <String>['places']);
        final payload = source.createdPayloads.single;
        expect(payload.keys, <String>{
          'name',
          'address',
          'location',
          'geohash',
          'added_by_uid',
          'created_at',
        });
        expect(payload['name'], 'Gelateria Milano');
        expect(payload['address'], 'Via Torino 1');
        expect(payload['location'], location);
        expect(payload['geohash'], GeoFirePoint(location).geohash);
        expect(payload['added_by_uid'], 'alice');
        expect(payload['created_at'], const PlaceServerTimestamp());
      },
    );

    test(
      'createPlace fails closed for empty invalid coordinates and UID',
      () async {
        for (final input
            in <({String name, String address, GeoPoint location})>[
              (name: ' ', address: 'Via A', location: const GeoPoint(45, 9)),
              (name: 'Gelato', address: ' ', location: const GeoPoint(45, 9)),
              (
                name: 'Gelato',
                address: 'Via A',
                location: const InvalidGeoPoint(),
              ),
            ]) {
          await expectLater(
            repository.createPlace(
              name: input.name,
              address: input.address,
              location: input.location,
            ),
            throwsA(isA<FormatException>()),
          );
        }
        for (final uid in <String?>[null, '', 'a/b']) {
          currentUid = uid;
          await expectLater(
            repository.createPlace(
              name: 'Gelato',
              address: 'Via A',
              location: const GeoPoint(45, 9),
            ),
            throwsA(isA<FormatException>()),
          );
        }

        expect(source.createdPayloads, isEmpty);
        expect(source.createdCollectionPaths, isEmpty);
      },
    );

    test(
      'createOrReadPlace uses one stable path and exact owned content',
      () async {
        const location = GeoPoint(45.4642, 9.19);
        const placeId = 'user_place_ABCDEFGHIJKLMNOPQRST';

        final place = await repository.createOrReadPlace(
          placeId: placeId,
          name: ' Gelateria Milano ',
          address: ' Via Torino 1 ',
          location: location,
        );

        expect(place.id, placeId);
        expect(source.createOrReadPaths, <String>['places/$placeId']);
        final payload = source.createOrReadPayloads.single;
        expect(payload.keys, <String>{
          'name',
          'address',
          'location',
          'geohash',
          'added_by_uid',
          'created_at',
        });
        expect(payload['name'], 'Gelateria Milano');
        expect(payload['address'], 'Via Torino 1');
        expect(payload['added_by_uid'], 'alice');
      },
    );

    test(
      'createOrReadPlace retry after post-commit read failure never duplicates',
      () async {
        const placeId = 'user_place_ABCDEFGHIJKLMNOPQRST';
        source.failFirstCreateOrReadAfterCommit = true;

        await expectLater(
          repository.createOrReadPlace(
            placeId: placeId,
            name: 'Nuova',
            address: 'Via 1',
            location: const GeoPoint(45, 9),
          ),
          throwsA(isA<StateError>()),
        );
        final place = await repository.createOrReadPlace(
          placeId: placeId,
          name: 'Nuova',
          address: 'Via 1',
          location: const GeoPoint(45, 9),
        );

        expect(place.id, placeId);
        expect(source.createOrReadPaths, <String>[
          'places/$placeId',
          'places/$placeId',
        ]);
        expect(source.createOrReadCommits, 1);
        expect(
          source.documents.keys.where((path) => path == 'places/$placeId'),
          hasLength(1),
        );
      },
    );

    test('createOrReadPlace rejects conflicting existing content', () async {
      const placeId = 'user_place_ABCDEFGHIJKLMNOPQRST';
      source.documents['places/$placeId'] = placeDocument(
        placeId,
        name: 'Altro nome',
      );

      await expectLater(
        repository.createOrReadPlace(
          placeId: placeId,
          name: 'Nuova',
          address: 'Via Uffici del Vicario 40',
          location: const GeoPoint(41.9, 12.5),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

final class InvalidGeoPoint extends GeoPoint {
  const InvalidGeoPoint() : super(0, 0);

  @override
  double get latitude => double.nan;
}

void expectQuery(
  PlaceStateQuery query, {
  required String field,
  required String? orderBy,
}) {
  expect(query.collectionPath, 'users/alice/place_states');
  expect(query.whereField, field);
  expect(query.isEqualTo, isTrue);
  expect(query.orderByField, orderBy);
  expect(query.descending, orderBy == null ? isFalse : isTrue);
}

void expectToggleWrite(
  RecordedStateWrite write,
  String field,
  String timestampField,
  bool value,
) {
  expect(write.data.keys, <String>{field, timestampField, 'updated_at'});
  expect(write.data[field], value);
  expect(
    write.data[timestampField],
    value ? const PlaceServerTimestamp() : const PlaceDelete(),
  );
  expect(write.data['updated_at'], const PlaceServerTimestamp());
}

List<FlutterErrorDetails> captureFlutterErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

PlaceDocument placeDocument(
  String id, {
  String name = 'Giolitti',
  String address = 'Via Uffici del Vicario 40',
  GeoPoint location = const GeoPoint(41.9, 12.5),
  String geohash = 'sr2yk',
}) {
  return PlaceDocument(
    id: id,
    data: <String, dynamic>{
      'name': name,
      'address': address,
      'location': location,
      'geohash': geohash,
      'added_by_uid': 'alice',
      'created_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    },
  );
}

final class RecordedStateWrite {
  const RecordedStateWrite(this.path, this.data);

  final String path;
  final Map<String, Object?> data;
}

final class RecordingPlaceStateDataSource implements PlaceStateDataSource {
  PlaceStateDocument? document;
  List<PlaceStateDocument> queryDocuments = <PlaceStateDocument>[];
  final List<String> watchedPaths = <String>[];
  final List<PlaceStateQuery> queries = <PlaceStateQuery>[];
  final List<RecordedStateWrite> writes = <RecordedStateWrite>[];

  @override
  Stream<PlaceStateDocument?> watchDocument(String path) {
    watchedPaths.add(path);
    return Stream<PlaceStateDocument?>.value(document);
  }

  @override
  Stream<List<PlaceStateDocument>> watchQuery(PlaceStateQuery query) {
    queries.add(query);
    return Stream<List<PlaceStateDocument>>.value(queryDocuments);
  }

  @override
  Future<void> mergeDocument(String path, Map<String, Object?> data) async {
    writes.add(RecordedStateWrite(path, Map<String, Object?>.from(data)));
  }
}

final class RecordingPlaceDataSource implements PlaceDataSource {
  List<PlaceDocument> catalogDocuments = <PlaceDocument>[];
  final Map<String, PlaceDocument?> documents = <String, PlaceDocument?>{};
  final Map<String, Object> readErrors = <String, Object>{};
  PlaceDocument? createdResult;
  final List<PlaceCatalogQuery> catalogQueries = <PlaceCatalogQuery>[];
  final List<String> readPaths = <String>[];
  final List<String> createdCollectionPaths = <String>[];
  final List<Map<String, Object?>> createdPayloads = <Map<String, Object?>>[];
  final List<String> createOrReadPaths = <String>[];
  final List<Map<String, Object?>> createOrReadPayloads =
      <Map<String, Object?>>[];
  bool failFirstCreateOrReadAfterCommit = false;
  int createOrReadCommits = 0;

  @override
  Stream<List<PlaceDocument>> watchCatalog(PlaceCatalogQuery query) {
    catalogQueries.add(query);
    return Stream<List<PlaceDocument>>.value(catalogDocuments);
  }

  @override
  Future<PlaceDocument?> readDocument(String path) async {
    readPaths.add(path);
    final error = readErrors[path];
    if (error != null) throw error;
    return documents[path];
  }

  @override
  Future<PlaceDocument> createDocument(
    String collectionPath,
    Map<String, Object?> data,
  ) async {
    createdCollectionPaths.add(collectionPath);
    createdPayloads.add(Map<String, Object?>.from(data));
    return createdResult!;
  }

  @override
  Future<PlaceDocument> createOrReadDocument(
    String path,
    Map<String, Object?> data,
  ) async {
    createOrReadPaths.add(path);
    createOrReadPayloads.add(Map<String, Object?>.from(data));
    var document = documents[path];
    if (document == null) {
      createOrReadCommits++;
      document = PlaceDocument(
        id: path.split('/').last,
        data: <String, dynamic>{
          for (final entry in data.entries)
            entry.key: entry.value is PlaceServerTimestamp
                ? Timestamp.fromDate(DateTime.utc(2026, 7, 15))
                : entry.value,
        },
      );
      documents[path] = document;
      if (failFirstCreateOrReadAfterCommit) {
        failFirstCreateOrReadAfterCommit = false;
        throw StateError('post-commit read unavailable');
      }
    }
    return document;
  }
}
