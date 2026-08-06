import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/place_aggregate.dart';

final class PlaceAggregateDocument {
  const PlaceAggregateDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class PlaceAggregateDataSource {
  Stream<PlaceAggregateDocument?> watchDocument(String path);
}

final class FirestorePlaceAggregateDataSource
    implements PlaceAggregateDataSource {
  FirestorePlaceAggregateDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<PlaceAggregateDocument?> watchDocument(String path) {
    return _firestore.doc(path).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return PlaceAggregateDocument(id: snapshot.id, data: data);
    });
  }
}

abstract interface class PlaceAggregateRepository {
  Stream<PlaceAggregate?> watchAggregate(String placeId);
}

final class PlaceAggregateRepositoryImpl implements PlaceAggregateRepository {
  PlaceAggregateRepositoryImpl(this._source);

  final PlaceAggregateDataSource _source;

  @override
  Stream<PlaceAggregate?> watchAggregate(String placeId) {
    requirePathSegment(placeId, 'placeId');
    return _source.watchDocument('place_aggregates/$placeId').map((document) {
      if (document == null) return null;
      if (document.id != placeId) {
        throw const FormatException('place aggregate: mismatched ID');
      }
      return PlaceAggregate.fromMap(document.data, document.id);
    });
  }
}
