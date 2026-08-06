import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_parsing.dart';
import '../models/place_state.dart';
import 'place_repository.dart';

export 'place_repository.dart' show PlaceServerTimestamp;

final class PlaceDelete {
  const PlaceDelete();

  @override
  bool operator ==(Object other) => other is PlaceDelete;

  @override
  int get hashCode => 2;
}

final class PlaceStateDocument {
  const PlaceStateDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class PlaceStateQuery {
  const PlaceStateQuery({
    required this.uid,
    required this.whereField,
    this.orderByField,
  });

  final String uid;
  final String whereField;
  final String? orderByField;
  final bool isEqualTo = true;

  String get collectionPath => 'users/$uid/place_states';
  bool get descending => orderByField != null;
}

abstract interface class PlaceStateDataSource {
  Stream<PlaceStateDocument?> watchDocument(String path);

  Stream<List<PlaceStateDocument>> watchQuery(PlaceStateQuery query);

  Future<void> mergeDocument(String path, Map<String, Object?> data);
}

final class FirestorePlaceStateDataSource implements PlaceStateDataSource {
  FirestorePlaceStateDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<PlaceStateDocument?> watchDocument(String path) {
    return _firestore.doc(path).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return PlaceStateDocument(id: snapshot.id, data: data);
    });
  }

  @override
  Stream<List<PlaceStateDocument>> watchQuery(PlaceStateQuery query) {
    Query<Map<String, dynamic>> firestoreQuery = _firestore
        .collection(query.collectionPath)
        .where(query.whereField, isEqualTo: query.isEqualTo);
    final orderByField = query.orderByField;
    if (orderByField != null) {
      firestoreQuery = firestoreQuery.orderBy(
        orderByField,
        descending: query.descending,
      );
    }
    return firestoreQuery.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) =>
                PlaceStateDocument(id: document.id, data: document.data()),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> mergeDocument(String path, Map<String, Object?> data) {
    return _firestore.doc(path).set(<String, Object?>{
      for (final entry in data.entries)
        entry.key: switch (entry.value) {
          PlaceServerTimestamp() => FieldValue.serverTimestamp(),
          PlaceDelete() => FieldValue.delete(),
          final value => value,
        },
    }, SetOptions(merge: true));
  }
}

abstract interface class PlaceStateRepository {
  Stream<PlaceState?> watchState(String uid, String placeId);

  Stream<List<PlaceState>> watchSaved(String uid);

  Stream<List<PlaceState>> watchFavorites(String uid);

  Stream<List<PlaceState>> watchLiked(String uid);

  Future<void> setSaved(String uid, String placeId, bool value);

  Future<void> setFavorite(String uid, String placeId, bool value);

  Future<void> setLiked(String uid, String placeId, bool value);

  Future<void> setNote(String uid, String placeId, String? note);
}

final class PlaceStateRepositoryImpl implements PlaceStateRepository {
  PlaceStateRepositoryImpl(this._source);

  final PlaceStateDataSource _source;

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) {
    _validate(uid, placeId);
    return _source
        .watchDocument('users/$uid/place_states/$placeId')
        .map((document) => document == null ? null : _parse(document));
  }

  @override
  Stream<List<PlaceState>> watchSaved(String uid) =>
      _watch(uid, field: 'saved', orderByField: 'saved_at');

  @override
  Stream<List<PlaceState>> watchFavorites(String uid) =>
      _watch(uid, field: 'favorite', orderByField: 'favorite_at');

  @override
  Stream<List<PlaceState>> watchLiked(String uid) =>
      _watch(uid, field: 'liked');

  Stream<List<PlaceState>> _watch(
    String uid, {
    required String field,
    String? orderByField,
  }) {
    requirePathSegment(uid, 'uid');
    final query = PlaceStateQuery(
      uid: uid,
      whereField: field,
      orderByField: orderByField,
    );
    return _source.watchQuery(query).map((documents) {
      final states = <PlaceState>[];
      for (final document in documents) {
        final state = _parse(document);
        if (state == null) continue;
        final matches = switch (field) {
          'saved' => state.saved,
          'favorite' => state.favorite,
          'liked' => state.liked,
          _ => false,
        };
        if (!matches) {
          parseOrReport<void>(
            path: '${query.collectionPath}/${document.id}',
            parse: () => throw FormatException('$field: expected true'),
          );
          continue;
        }
        states.add(state);
      }
      return List<PlaceState>.unmodifiable(states);
    });
  }

  @override
  Future<void> setSaved(String uid, String placeId, bool value) =>
      _setBoolean(uid, placeId, 'saved', 'saved_at', value);

  @override
  Future<void> setFavorite(String uid, String placeId, bool value) =>
      _setBoolean(uid, placeId, 'favorite', 'favorite_at', value);

  @override
  Future<void> setLiked(String uid, String placeId, bool value) =>
      _setBoolean(uid, placeId, 'liked', 'liked_at', value);

  Future<void> _setBoolean(
    String uid,
    String placeId,
    String field,
    String timestampField,
    bool value,
  ) {
    _validate(uid, placeId);
    return _source
        .mergeDocument('users/$uid/place_states/$placeId', <String, Object?>{
          field: value,
          timestampField: value
              ? const PlaceServerTimestamp()
              : const PlaceDelete(),
          'updated_at': const PlaceServerTimestamp(),
        });
  }

  @override
  Future<void> setNote(String uid, String placeId, String? note) {
    _validate(uid, placeId);
    final normalized = note?.trim();
    if (normalized != null && normalized.length > 500) {
      throw const FormatException('note: exceeds 500 characters');
    }
    return _source
        .mergeDocument('users/$uid/place_states/$placeId', <String, Object?>{
          'note': normalized ?? const PlaceDelete(),
          'updated_at': const PlaceServerTimestamp(),
        });
  }

  PlaceState? _parse(PlaceStateDocument document) => parseOrReport<PlaceState>(
    path: 'place_states/${document.id}',
    parse: () => PlaceState.fromMap(document.data, document.id),
  );

  void _validate(String uid, String placeId) {
    requirePathSegment(uid, 'uid');
    requirePathSegment(placeId, 'placeId');
  }
}
