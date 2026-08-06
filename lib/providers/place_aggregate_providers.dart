import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/place_aggregate.dart';
import '../repositories/place_aggregate_repository.dart';
import 'auth_provider.dart';

final placeAggregateDataSourceProvider = Provider<PlaceAggregateDataSource>((
  ref,
) {
  return FirestorePlaceAggregateDataSource(ref.watch(firestoreProvider));
});

final placeAggregateRepositoryProvider = Provider<PlaceAggregateRepository>((
  ref,
) {
  return PlaceAggregateRepositoryImpl(
    ref.watch(placeAggregateDataSourceProvider),
  );
});

final placeAggregateForIdProvider = StreamProvider.autoDispose
    .family<PlaceAggregate?, String>((ref, placeId) {
      return ref
          .watch(placeAggregateRepositoryProvider)
          .watchAggregate(placeId);
    });

final placeAggregateProvider = Provider.autoDispose
    .family<AsyncValue<PlaceAggregate?>, String>((ref, placeId) {
      if (ref.watch(currentUidProvider) == null) {
        return const AsyncData<PlaceAggregate?>(null);
      }
      return ref.watch(placeAggregateForIdProvider(placeId));
    });
