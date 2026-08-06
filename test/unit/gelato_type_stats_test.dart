import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/utils/gelato_type_stats.dart';

CheckIn typedCheckIn(String id, String typeId, DateTime createdAt) {
  return CheckIn.legacy(
    id: id.padRight(20, '_'),
    userId: 'user',
    userSummary: const {},
    placeId: 'place',
    placeName: 'Gelateria',
    photoUrl: 'photo.jpg',
    isLivePhoto: false,
    rating: 5,
    gelatoType: GelatoType(id: typeId, name: typeId, sortOrder: 0),
    flavors: const [],
    likedByUids: const [],
    wishlistedByUids: const [],
    createdAt: createdAt,
  );
}

CheckIn legacyCheckIn() {
  return CheckIn.legacy(
    id: 'legacy'.padRight(20, '_'),
    userId: 'user',
    userSummary: const {},
    placeId: 'place',
    placeName: 'Gelateria',
    photoUrl: 'photo.jpg',
    isLivePhoto: false,
    rating: 5,
    flavors: const [],
    likedByUids: const [],
    wishlistedByUids: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('gelato type statistics', () {
    test('ranks by frequency then latest use and fills to four', () {
      final result = compactGelatoTypes(
        catalog: defaultGelatoTypes,
        checkIns: [
          typedCheckIn('old-cono', 'cono', DateTime(2026, 1, 1)),
          typedCheckIn('new-cono', 'cono', DateTime(2026, 2, 1)),
          typedCheckIn('coppetta', 'coppetta', DateTime(2026, 3, 1)),
          typedCheckIn('brioche', 'brioche', DateTime(2026, 4, 1)),
        ],
      );

      expect(result.map((type) => type.id), [
        'cono',
        'brioche',
        'coppetta',
        'vaschetta',
      ]);
    });

    test('keeps a selected type visible outside the first four', () {
      final result = compactGelatoTypes(
        catalog: defaultGelatoTypes,
        checkIns: const [],
        selected: defaultGelatoTypes[10],
      );

      expect(result.map((type) => type.id), [
        'cono',
        'coppetta',
        'brioche',
        'vaschetta',
        'semifreddo',
      ]);
    });

    test('favorite breaks ties using the most recent usage', () {
      final favorite = favoriteGelatoType([
        typedCheckIn('cono', 'cono', DateTime(2026, 1, 1)),
        typedCheckIn('coppetta', 'coppetta', DateTime(2026, 2, 1)),
      ]);

      expect(favorite?.id, 'coppetta');
    });

    test('favorite ignores legacy check-ins', () {
      expect(favoriteGelatoType([legacyCheckIn()]), isNull);
    });

    test('profile value is a dash when no typed check-ins exist', () {
      expect(favoriteGelatoTypeLabel([legacyCheckIn()]), '—');
    });

    test('profile value uses the favorite type name', () {
      expect(
        favoriteGelatoTypeLabel([
          typedCheckIn('first', 'cono', DateTime(2026, 1, 1)),
          typedCheckIn('second', 'cono', DateTime(2026, 2, 1)),
        ]),
        'cono',
      );
    });
  });
}
