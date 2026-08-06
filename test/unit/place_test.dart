// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/legacy_place_social_state.dart';
import 'package:gelatino/models/place.dart';

class FakeDocumentSnapshot implements DocumentSnapshot {
  FakeDocumentSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final location = const GeoPoint(41.9028, 12.4964);
  final createdAt = DateTime(2026, 7, 14, 12);

  Map<String, dynamic> canonicalPlace() => <String, dynamic>{
    'name': 'Giolitti',
    'address': 'Via Uffici del Vicario 40',
    'location': location,
    'geohash': 'sr2yk',
    'added_by_uid': 'user-1',
    'created_at': Timestamp.fromDate(createdAt),
  };

  test('canonical parser requires GeoPoint and Timestamp', () {
    final place = Place.fromFirestore(
      FakeDocumentSnapshot('place-1', canonicalPlace()),
    );
    expect(place.location, location);
    expect(place.createdAt, createdAt);

    expect(
      () => Place.fromFirestore(
        FakeDocumentSnapshot(
          'place-1',
          canonicalPlace()..['location'] = 'Rome',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => Place.fromFirestore(
        FakeDocumentSnapshot('place-1', canonicalPlace()..['created_at'] = 0),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('canonical map contains catalog fields only', () {
    final map = Place.fromFirestore(
      FakeDocumentSnapshot('place-1', canonicalPlace()),
    ).toMap();

    expect(map.keys, <String>{
      'name',
      'address',
      'location',
      'geohash',
      'added_by_uid',
      'created_at',
    });
    expect(map, isNot(contains('liked_by_uids')));
    expect(map, isNot(contains('favorited_by_uids')));
    expect(map, isNot(contains('wishlisted_by_uids')));
  });

  test('legacy social arrays require the named adapter', () {
    final legacy = canonicalPlace()
      ..addAll(<String, dynamic>{
        'liked_by_uids': <String>['alice'],
        'favorited_by_uids': <String>['bob'],
        'wishlisted_by_uids': <String>['charlie'],
      });

    final canonical = Place.fromFirestore(
      FakeDocumentSnapshot('place-1', legacy),
    );
    final adapted = LegacyPlaceSocialState.fromFirestore(
      FakeDocumentSnapshot('place-1', legacy),
    );

    expect(canonical.id, 'place-1');
    expect(adapted.likedByUids, <String>['alice']);
    expect(adapted.favoritedByUids, <String>['bob']);
    expect(adapted.wishlistedByUids, <String>['charlie']);
  });

  test('legacy adapter rejects mixed social list entries', () {
    final legacy = canonicalPlace()
      ..addAll(<String, dynamic>{
        'liked_by_uids': <Object>['alice', 2],
        'favorited_by_uids': <String>[],
        'wishlisted_by_uids': <String>[],
      });
    expect(
      () => LegacyPlaceSocialState.fromFirestore(
        FakeDocumentSnapshot('place-1', legacy),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('migration-only adapter defensively copies social arrays', () {
    final liked = <String>['alice'];
    final adapted = LegacyPlaceSocialState(
      placeId: 'place-1',
      likedByUids: liked,
      favoritedByUids: const <String>[],
      wishlistedByUids: const <String>[],
    );

    liked.add('bob');
    expect(adapted.likedByUids, <String>['alice']);
    expect(() => adapted.likedByUids.add('carol'), throwsUnsupportedError);
  });
}
