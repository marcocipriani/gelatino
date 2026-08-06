import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/firestore_parsing.dart';
import '../models/place.dart';

final class PlaceServerTimestamp {
  const PlaceServerTimestamp();

  @override
  bool operator ==(Object other) => other is PlaceServerTimestamp;

  @override
  int get hashCode => 1;
}

final class PlaceDocument {
  const PlaceDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class PlaceCatalogQuery {
  const PlaceCatalogQuery();

  final String collectionPath = 'places';
}

abstract interface class PlaceDataSource {
  Stream<List<PlaceDocument>> watchCatalog(PlaceCatalogQuery query);

  Future<PlaceDocument?> readDocument(String path);

  Future<PlaceDocument> createDocument(
    String collectionPath,
    Map<String, Object?> data,
  );

  Future<PlaceDocument> createOrReadDocument(
    String path,
    Map<String, Object?> data,
  );
}

final class FirestorePlaceDataSource implements PlaceDataSource {
  FirestorePlaceDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PlaceDocument>> watchCatalog(PlaceCatalogQuery query) {
    return _firestore
        .collection(query.collectionPath)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    PlaceDocument(id: document.id, data: document.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<PlaceDocument?> readDocument(String path) async {
    final snapshot = await _firestore.doc(path).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return PlaceDocument(id: snapshot.id, data: data);
  }

  @override
  Future<PlaceDocument> createDocument(
    String collectionPath,
    Map<String, Object?> data,
  ) async {
    final reference = await _firestore
        .collection(collectionPath)
        .add(<String, Object?>{
          for (final entry in data.entries)
            entry.key: entry.value is PlaceServerTimestamp
                ? FieldValue.serverTimestamp()
                : entry.value,
        });
    final snapshot = await reference.get();
    final created = snapshot.data();
    if (!snapshot.exists || created == null) {
      throw StateError('Created place document is unavailable.');
    }
    return PlaceDocument(id: snapshot.id, data: created);
  }

  @override
  Future<PlaceDocument> createOrReadDocument(
    String path,
    Map<String, Object?> data,
  ) async {
    final reference = _firestore.doc(path);
    final existing = await _firestore.runTransaction<PlaceDocument?>((
      transaction,
    ) async {
      final snapshot = await transaction.get(reference);
      final existingData = snapshot.data();
      if (snapshot.exists) {
        if (existingData == null) {
          throw StateError('Existing place document is unavailable.');
        }
        return PlaceDocument(id: snapshot.id, data: existingData);
      }
      transaction.set(reference, _firestorePlaceData(data));
      return null;
    });
    if (existing != null) return existing;
    final snapshot = await reference.get();
    final created = snapshot.data();
    if (!snapshot.exists || created == null) {
      throw StateError('Created place document is unavailable.');
    }
    return PlaceDocument(id: snapshot.id, data: created);
  }
}

Map<String, Object?> _firestorePlaceData(Map<String, Object?> data) =>
    <String, Object?>{
      for (final entry in data.entries)
        entry.key: entry.value is PlaceServerTimestamp
            ? FieldValue.serverTimestamp()
            : entry.value,
    };

abstract interface class PlaceRepository {
  Stream<List<Place>> watchPlaces();

  Future<List<Place>> readPlaces(List<String> placeIds);

  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  });

  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  });
}

typedef CurrentUidReader = String? Function();

final class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl(this._source, this._readCurrentUid);

  final PlaceDataSource _source;
  final CurrentUidReader _readCurrentUid;

  @override
  Stream<List<Place>> watchPlaces() {
    return _source.watchCatalog(const PlaceCatalogQuery()).map((documents) {
      final places = <Place>[];
      for (final document in documents) {
        final place = _parsePlace(document);
        if (place != null) places.add(place);
      }
      places.sort((left, right) {
        final byName = left.name.compareTo(right.name);
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
      return List<Place>.unmodifiable(places);
    });
  }

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) async {
    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final placeId in placeIds) {
      requirePathSegment(placeId, 'placeId');
      if (seen.add(placeId)) uniqueIds.add(placeId);
    }

    final placesById = <String, Place>{};
    for (var start = 0; start < uniqueIds.length; start += 30) {
      final end = (start + 30).clamp(0, uniqueIds.length);
      final batch = uniqueIds.sublist(start, end);
      final documents = await Future.wait(
        batch.map((placeId) => _source.readDocument('places/$placeId')),
      );
      for (final document in documents.whereType<PlaceDocument>()) {
        final place = _parsePlace(document);
        if (place != null && seen.contains(place.id)) {
          placesById[place.id] = place;
        }
      }
    }
    return List<Place>.unmodifiable(
      uniqueIds.map((placeId) => placesById[placeId]).whereType<Place>(),
    );
  }

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    final payload = _newPlacePayload(
      name: name,
      address: address,
      location: location,
    );
    final document = await _source.createDocument('places', payload);
    return Place.fromMap(document.data, document.id);
  }

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    requirePathSegment(placeId, 'placeId');
    final payload = _newPlacePayload(
      name: name,
      address: address,
      location: location,
    );
    final document = await _source.createOrReadDocument(
      'places/$placeId',
      payload,
    );
    final place = Place.fromMap(document.data, document.id);
    final expectedLocation = payload['location']! as GeoPoint;
    if (place.id != placeId ||
        place.name != payload['name'] ||
        place.address != payload['address'] ||
        place.location.latitude != expectedLocation.latitude ||
        place.location.longitude != expectedLocation.longitude ||
        place.geohash != payload['geohash'] ||
        place.addedByUid != payload['added_by_uid']) {
      throw StateError('Existing place conflicts with this draft.');
    }
    return place;
  }

  Map<String, Object?> _newPlacePayload({
    required String name,
    required String address,
    required GeoPoint location,
  }) {
    final normalizedName = name.trim();
    final normalizedAddress = address.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('name: must not be empty');
    }
    if (normalizedAddress.isEmpty) {
      throw const FormatException('address: must not be empty');
    }
    if (!location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude < -90 ||
        location.latitude > 90 ||
        location.longitude < -180 ||
        location.longitude > 180) {
      throw const FormatException('location: invalid coordinates');
    }
    final uid = _readCurrentUid();
    if (uid == null) throw const FormatException('uid: invalid ID');
    requirePathSegment(uid, 'uid');
    return <String, Object?>{
      'name': normalizedName,
      'address': normalizedAddress,
      'location': location,
      'geohash': GeoFirePoint(location).geohash,
      'added_by_uid': uid,
      'created_at': const PlaceServerTimestamp(),
    };
  }

  Place? _parsePlace(PlaceDocument document) => parseOrReport<Place>(
    path: 'places/${document.id}',
    parse: () => Place.fromMap(document.data, document.id),
  );
}
