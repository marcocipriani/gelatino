import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place_aggregate.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_aggregate_providers.dart';
import 'package:gelatino/repositories/place_aggregate_repository.dart';

void main() {
  test('repository reads the exact place aggregate document path', () async {
    final source = FakePlaceAggregateDataSource(
      PlaceAggregateDocument(
        id: 'place-1',
        data: <String, dynamic>{
          'check_in_count': 2,
          'rating_sum': 9,
          'rating_average': 4.5,
          'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
        },
      ),
    );
    final repository = PlaceAggregateRepositoryImpl(source);

    final value = await repository.watchAggregate('place-1').first;

    expect(source.paths, <String>['place_aggregates/place-1']);
    expect(value?.placeId, 'place-1');
    expect(value?.checkInCount, 2);
    expect(value?.ratingAverage, 4.5);
  });

  test('repository propagates malformed authoritative documents', () async {
    final source = FakePlaceAggregateDataSource(
      PlaceAggregateDocument(
        id: 'place-1',
        data: <String, dynamic>{
          'check_in_count': 2,
          'rating_sum': 9,
          'rating_average': '4.5',
          'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
        },
      ),
    );

    expect(
      PlaceAggregateRepositoryImpl(source).watchAggregate('place-1').first,
      throwsA(isA<FormatException>()),
    );
  });

  test('signed-out provider does not attempt an authenticated read', () {
    final repository = FakePlaceAggregateRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(null),
        placeAggregateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(placeAggregateProvider('place-1')).value, isNull);
    expect(repository.placeIds, isEmpty);
  });

  test('signed-in provider exposes the authoritative aggregate', () async {
    final repository = FakePlaceAggregateRepository(
      PlaceAggregate(
        placeId: 'place-1',
        checkInCount: 2,
        ratingSum: 9,
        ratingAverage: 4.5,
        updatedAt: DateTime(2026, 7, 15),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        placeAggregateRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      placeAggregateProvider('place-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.pump();

    expect(
      container.read(placeAggregateProvider('place-1')).value?.ratingSum,
      9,
    );
    expect(repository.placeIds, <String>['place-1']);
  });
}

final class FakePlaceAggregateDataSource implements PlaceAggregateDataSource {
  FakePlaceAggregateDataSource(this.document);

  final PlaceAggregateDocument? document;
  final List<String> paths = <String>[];

  @override
  Stream<PlaceAggregateDocument?> watchDocument(String path) {
    paths.add(path);
    return Stream<PlaceAggregateDocument?>.value(document);
  }
}

final class FakePlaceAggregateRepository implements PlaceAggregateRepository {
  FakePlaceAggregateRepository([this.aggregate]);

  final PlaceAggregate? aggregate;
  final List<String> placeIds = <String>[];

  @override
  Stream<PlaceAggregate?> watchAggregate(String placeId) {
    placeIds.add(placeId);
    return Stream<PlaceAggregate?>.value(aggregate);
  }
}
