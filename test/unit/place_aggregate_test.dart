import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place_aggregate.dart';

void main() {
  final updatedAt = DateTime(2026, 7, 15, 12);

  Map<String, dynamic> aggregate() => <String, dynamic>{
    'check_in_count': 3,
    'rating_sum': 12,
    'rating_average': 4,
    'updated_at': Timestamp.fromDate(updatedAt),
  };

  test('parses the exact server-owned place aggregate projection', () {
    final value = PlaceAggregate.fromMap(aggregate(), 'place-1');

    expect(value.placeId, 'place-1');
    expect(value.checkInCount, 3);
    expect(value.ratingSum, 12);
    expect(value.ratingAverage, 4);
    expect(value.updatedAt, updatedAt);
  });

  test('accepts the canonical empty aggregate', () {
    final value = PlaceAggregate.fromMap(<String, dynamic>{
      'check_in_count': 0,
      'rating_sum': 0,
      'rating_average': 0.0,
      'updated_at': Timestamp.fromDate(updatedAt),
    }, 'place-1');

    expect(value.checkInCount, 0);
    expect(value.ratingAverage, 0);
  });

  test('rejects fields outside the aggregate allowlist', () {
    final privateData = aggregate()..['latest_author_uid'] = 'alice';

    expect(
      () => PlaceAggregate.fromMap(privateData, 'place-1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects incomplete or internally inconsistent aggregates', () {
    final missing = aggregate()..remove('rating_sum');
    final negative = aggregate()..['check_in_count'] = -1;
    final fractionalCount = aggregate()..['check_in_count'] = 3.5;
    final impossibleSum = aggregate()..['rating_sum'] = 16;
    final inconsistentAverage = aggregate()..['rating_average'] = 3.5;

    for (final data in <Map<String, dynamic>>[
      missing,
      negative,
      fractionalCount,
      impossibleSum,
      inconsistentAverage,
    ]) {
      expect(
        () => PlaceAggregate.fromMap(data, 'place-1'),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('rejects malformed place IDs', () {
    expect(
      () => PlaceAggregate.fromMap(aggregate(), 'nested/place'),
      throwsA(isA<FormatException>()),
    );
  });
}
