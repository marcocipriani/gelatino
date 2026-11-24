// ignore_for_file: subtype_of_sealed_class, deprecated_member_use_from_same_package

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in.dart';
import 'package:gelatino/models/flavor.dart';

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
  const checkInId = 'checkin_123456789012';
  final createdAt = DateTime(2026, 7, 14, 12);
  final updatedAt = DateTime(2026, 7, 14, 13);

  Map<String, dynamic> canonicalCheckIn() => <String, dynamic>{
    'user_id': 'alice',
    'user_snapshot': <String, dynamic>{
      'display_name': 'Alice',
      'username': 'alice-gelato',
      'avatar_path': null,
    },
    'place_id': 'place-1',
    'place_snapshot': <String, dynamic>{
      'name': 'Giolitti',
      'address': 'Via Uffici del Vicario 40',
    },
    'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'rating': 5,
    'review_text': 'Ottimo',
    'tagged_user_ids': <String>['bob'],
    'photo_storage_path': 'check_ins/alice/$checkInId/1.jpg',
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    'schema_version': 2,
  };

  Map<String, dynamic> legacyCheckIn() => <String, dynamic>{
    'user_id': 'alice',
    'user_summary': <String, dynamic>{
      'username': 'Alice',
      'avatar_url': 'https://example.test/alice.jpg',
    },
    'place_id': 'place-1',
    'place_name': 'Giolitti',
    'photo_url': 'https://example.test/check-in.jpg',
    'is_live_photo': false,
    'review_text': 'Ottimo',
    'rating': 5,
    'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
    ],
    'liked_by_uids': <String>['bob'],
    'wishlisted_by_uids': <String>[],
    'location': const GeoPoint(41.9, 12.5),
    'created_at': Timestamp.fromDate(createdAt),
    'tagged_user_uids': <String>['bob'],
    'tagged_user_names': <String, String>{'bob': 'Bob'},
  };

  test('canonical v2 parses strict snapshots and server timestamps', () {
    final checkIn = CheckIn.fromFirestore(
      FakeDocumentSnapshot(checkInId, canonicalCheckIn()),
    );

    expect(checkIn.userSnapshot['display_name'], 'Alice');
    expect(checkIn.placeSnapshot['name'], 'Giolitti');
    expect(checkIn.photoStoragePath, 'check_ins/alice/$checkInId/1.jpg');
    expect(checkIn.taggedUserIds, <String>['bob']);
    expect(checkIn.createdAt, createdAt);
    expect(checkIn.updatedAt, updatedAt);
  });

  test('canonical parser rejects legacy schema instead of guessing', () {
    expect(
      () => CheckIn.fromFirestore(
        FakeDocumentSnapshot(checkInId, legacyCheckIn()),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('legacy adapter rejects canonical schema instead of guessing', () {
    expect(
      () => CheckIn.fromLegacyFirestore(
        FakeDocumentSnapshot(checkInId, canonicalCheckIn()),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('named legacy adapter parses only legacy keys', () {
    final checkIn = CheckIn.fromLegacyFirestore(
      FakeDocumentSnapshot(checkInId, legacyCheckIn()),
    );

    expect(checkIn.userSnapshot['username'], 'Alice');
    expect(checkIn.placeSnapshot['name'], 'Giolitti');
    expect(checkIn.photoStoragePath, 'https://example.test/check-in.jpg');
    expect(checkIn.taggedUserIds, <String>['bob']);
    expect(checkIn.schemaVersion, 1);
  });

  test('canonical parser validates rating IDs path and nested shapes', () {
    final badRating = canonicalCheckIn()..['rating'] = 5.0;
    expect(
      () => CheckIn.fromFirestore(FakeDocumentSnapshot(checkInId, badRating)),
      throwsA(isA<FormatException>()),
    );

    final badPhoto = canonicalCheckIn()
      ..['photo_storage_path'] = 'check_ins/alice/other/1.jpg';
    expect(
      () => CheckIn.fromFirestore(FakeDocumentSnapshot(checkInId, badPhoto)),
      throwsA(isA<FormatException>()),
    );

    final badFlavor = canonicalCheckIn()
      ..['flavors'] = <Object>[
        <String, dynamic>{'id': 'pistacchio', 'name': 3},
      ];
    expect(
      () => CheckIn.fromFirestore(FakeDocumentSnapshot(checkInId, badFlavor)),
      throwsA(isA<FormatException>()),
    );

    final badSnapshot = canonicalCheckIn()
      ..['user_snapshot'] = <String, dynamic>{
        'display_name': 'Alice',
        'username': 'alice',
        'avatar_path': null,
        'email': 'private@example.test',
      };
    expect(
      () => CheckIn.fromFirestore(FakeDocumentSnapshot(checkInId, badSnapshot)),
      throwsA(isA<FormatException>()),
    );
  });

  test('check-in IDs match the backend contract exactly', () {
    for (final invalid in <String>[
      'short',
      'checkin.id.with.dots.1234',
      List.filled(65, 'a').join(),
    ]) {
      expect(
        () => CheckIn.fromFirestore(
          FakeDocumentSnapshot(invalid, canonicalCheckIn()),
        ),
        throwsA(isA<FormatException>()),
        reason: invalid,
      );
    }
  });

  test('test constructor defensively copies collections', () {
    final flavors = <Flavor>[Flavor(id: 'cup', name: 'Coppetta')];
    final checkIn = CheckIn.forTesting(
      id: checkInId,
      flavors: flavors,
      createdAt: createdAt,
    );

    flavors.add(Flavor(id: 'cone', name: 'Cono'));
    expect(checkIn.flavors, hasLength(1));
    expect(() => checkIn.flavors.clear(), throwsUnsupportedError);
  });
}
