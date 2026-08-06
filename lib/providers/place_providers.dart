import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/firestore_parsing.dart';
import '../models/place.dart';
import '../models/place_state.dart';
import '../repositories/place_repository.dart';
import '../repositories/place_state_repository.dart';
import 'auth_provider.dart';

final placeDataSourceProvider = Provider<PlaceDataSource>((ref) {
  return FirestorePlaceDataSource(ref.watch(firestoreProvider));
});

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepositoryImpl(
    ref.watch(placeDataSourceProvider),
    () => ref.read(currentUidProvider),
  );
});

final placeStateDataSourceProvider = Provider<PlaceStateDataSource>((ref) {
  return FirestorePlaceStateDataSource(ref.watch(firestoreProvider));
});

final placeStateRepositoryProvider = Provider<PlaceStateRepository>((ref) {
  return PlaceStateRepositoryImpl(ref.watch(placeStateDataSourceProvider));
});

final placesProvider = StreamProvider<List<Place>>((ref) {
  return ref.watch(placeRepositoryProvider).watchPlaces();
});

final placeByIdProvider = Provider.family<Place?, String>((ref, placeId) {
  return ref
      .watch(placesProvider)
      .value
      ?.where((place) => place.id == placeId)
      .firstOrNull;
});

typedef UserPlaceKey = ({String uid, String placeId});

final placeStateForUidProvider = StreamProvider.autoDispose
    .family<PlaceState?, UserPlaceKey>((ref, key) {
      return ref
          .watch(placeStateRepositoryProvider)
          .watchState(key.uid, key.placeId);
    });

final savedPlaceStatesForUidProvider = StreamProvider.autoDispose
    .family<List<PlaceState>, String>((ref, uid) {
      return ref.watch(placeStateRepositoryProvider).watchSaved(uid);
    });

final favoritePlaceStatesForUidProvider = StreamProvider.autoDispose
    .family<List<PlaceState>, String>((ref, uid) {
      return ref.watch(placeStateRepositoryProvider).watchFavorites(uid);
    });

final likedPlaceStatesForUidProvider = StreamProvider.autoDispose
    .family<List<PlaceState>, String>((ref, uid) {
      return ref.watch(placeStateRepositoryProvider).watchLiked(uid);
    });

final savedPlacesForUidProvider = FutureProvider.autoDispose
    .family<List<Place>, String>((ref, uid) async {
      final states = await ref.watch(
        savedPlaceStatesForUidProvider(uid).future,
      );
      return ref
          .watch(placeRepositoryProvider)
          .readPlaces(_orderedPlaceIds(states));
    });

final favoritePlacesForUidProvider = FutureProvider.autoDispose
    .family<List<Place>, String>((ref, uid) async {
      final states = await ref.watch(
        favoritePlaceStatesForUidProvider(uid).future,
      );
      return ref
          .watch(placeRepositoryProvider)
          .readPlaces(_orderedPlaceIds(states));
    });

final likedPlacesForUidProvider = FutureProvider.autoDispose
    .family<List<Place>, String>((ref, uid) async {
      final states = await ref.watch(
        likedPlaceStatesForUidProvider(uid).future,
      );
      return ref
          .watch(placeRepositoryProvider)
          .readPlaces(_orderedPlaceIds(states));
    });

final savedPlacesProvider = Provider.autoDispose<AsyncValue<List<Place>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData<List<Place>>(<Place>[]);
  return ref.watch(savedPlacesForUidProvider(uid));
});

final favoritePlacesProvider = Provider.autoDispose<AsyncValue<List<Place>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData<List<Place>>(<Place>[]);
  return ref.watch(favoritePlacesForUidProvider(uid));
});

final likedPlacesProvider = Provider.autoDispose<AsyncValue<List<Place>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData<List<Place>>(<Place>[]);
  return ref.watch(likedPlacesForUidProvider(uid));
});

final placesForStateFilterProvider = Provider.autoDispose
    .family<AsyncValue<List<Place>>, String>((ref, filter) {
      return switch (filter) {
        'liked' => ref.watch(likedPlacesProvider),
        'favorite' => ref.watch(favoritePlacesProvider),
        'wishlist' => ref.watch(savedPlacesProvider),
        _ => const AsyncData<List<Place>>(<Place>[]),
      };
    });

final placeStateProvider = Provider.autoDispose
    .family<AsyncValue<PlaceState?>, String>((ref, placeId) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData<PlaceState?>(null);
      final remote = ref.watch(
        placeStateForUidProvider((uid: uid, placeId: placeId)),
      );
      final optimistic = ref.watch(placeStateControllerProvider);
      if (!optimistic.hasPending(placeId)) return remote;
      final optimisticState = optimistic.states[placeId];
      if (optimisticState == null) return remote;
      if (!remote.hasValue) return AsyncData<PlaceState?>(optimisticState);
      final canonical = remote.value ?? PlaceState.empty(placeId);
      return AsyncData<PlaceState?>(
        _mergePendingPlaceState(
          canonical: canonical,
          optimistic: optimisticState,
          pending: optimistic,
        ),
      );
    });

PlaceState _mergePendingPlaceState({
  required PlaceState canonical,
  required PlaceState optimistic,
  required PlaceStateControllerSnapshot pending,
}) {
  final placeId = canonical.placeId;
  final savedPending = pending.hasPending(placeId, PlaceStateField.saved);
  final favoritePending = pending.hasPending(placeId, PlaceStateField.favorite);
  final likedPending = pending.hasPending(placeId, PlaceStateField.liked);
  return PlaceState(
    placeId: placeId,
    saved: savedPending ? optimistic.saved : canonical.saved,
    savedAt: savedPending ? optimistic.savedAt : canonical.savedAt,
    favorite: favoritePending ? optimistic.favorite : canonical.favorite,
    favoriteAt: favoritePending ? optimistic.favoriteAt : canonical.favoriteAt,
    liked: likedPending ? optimistic.liked : canonical.liked,
    likedAt: likedPending ? optimistic.likedAt : canonical.likedAt,
    note: canonical.note,
    updatedAt: canonical.updatedAt,
  );
}

List<String> _orderedPlaceIds(List<PlaceState> states) {
  final seen = <String>{};
  return List<String>.unmodifiable(
    states.map((state) => state.placeId).where(seen.add),
  );
}

enum PlaceStateField { saved, favorite, liked }

typedef PlaceStateOperationKey = ({String placeId, PlaceStateField field});

final class PlaceStateFailure implements Exception {
  const PlaceStateFailure({
    required this.field,
    required this.message,
    required this.cause,
  });

  final PlaceStateField field;
  final String message;
  final Object cause;

  @override
  String toString() => message;
}

final class PlaceStateControllerSnapshot {
  PlaceStateControllerSnapshot({
    Map<String, PlaceState> states = const <String, PlaceState>{},
    Set<PlaceStateOperationKey> pendingKeys = const <PlaceStateOperationKey>{},
    Map<PlaceStateOperationKey, PlaceStateFailure> failures =
        const <PlaceStateOperationKey, PlaceStateFailure>{},
  }) : states = Map<String, PlaceState>.unmodifiable(states),
       pendingKeys = Set<PlaceStateOperationKey>.unmodifiable(pendingKeys),
       failures = Map<PlaceStateOperationKey, PlaceStateFailure>.unmodifiable(
         failures,
       );

  PlaceStateControllerSnapshot.exact({
    required this.states,
    required this.pendingKeys,
    required Map<PlaceStateOperationKey, PlaceStateFailure> failures,
  }) : failures = Map<PlaceStateOperationKey, PlaceStateFailure>.unmodifiable(
         failures,
       );

  final Map<String, PlaceState> states;
  final Set<PlaceStateOperationKey> pendingKeys;
  final Map<PlaceStateOperationKey, PlaceStateFailure> failures;

  PlaceStateFailure? get failure =>
      failures.isEmpty ? null : failures.values.last;

  bool hasPending(String placeId, [PlaceStateField? field]) => field == null
      ? pendingKeys.any((key) => key.placeId == placeId)
      : pendingKeys.contains((placeId: placeId, field: field));

  PlaceStateFailure? failureFor(String placeId, PlaceStateField field) =>
      failures[(placeId: placeId, field: field)];
}

final placeStateControllerProvider =
    NotifierProvider<PlaceStateController, PlaceStateControllerSnapshot>(
      PlaceStateController.new,
    );

final class PlaceStateController
    extends Notifier<PlaceStateControllerSnapshot> {
  String? _activeUid;
  int _identityGeneration = 0;
  final Map<PlaceStateOperationKey, int> _versions =
      <PlaceStateOperationKey, int>{};

  @override
  PlaceStateControllerSnapshot build() {
    final uid = ref.watch(currentUidProvider);
    if (_activeUid != uid) {
      _activeUid = uid;
      _identityGeneration++;
      _versions.clear();
    }
    return PlaceStateControllerSnapshot();
  }

  Future<void> toggleSaved(String placeId, {required PlaceState? current}) {
    return _toggle(placeId, PlaceStateField.saved, current);
  }

  Future<void> toggleFavorite(String placeId, {required PlaceState? current}) {
    return _toggle(placeId, PlaceStateField.favorite, current);
  }

  Future<void> toggleLiked(String placeId, {required PlaceState? current}) {
    return _toggle(placeId, PlaceStateField.liked, current);
  }

  Future<void> _toggle(
    String placeId,
    PlaceStateField field,
    PlaceState? current,
  ) async {
    requirePathSegment(placeId, 'placeId');
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      throw PlaceStateFailure(
        field: field,
        message: 'Accedi per modificare questa gelateria.',
        cause: const _UnauthenticatedPlaceStateCause(),
      );
    }
    requirePathSegment(uid, 'uid');
    final identityGeneration = _identityGeneration;
    final before = state;
    final base = before.hasPending(placeId)
        ? before.states[placeId] ?? current ?? PlaceState.empty(placeId)
        : current ?? PlaceState.empty(placeId);
    final next = switch (field) {
      PlaceStateField.saved => base.copyWith(saved: !base.saved),
      PlaceStateField.favorite => base.copyWith(favorite: !base.favorite),
      PlaceStateField.liked => base.copyWith(liked: !base.liked),
    };
    final key = (placeId: placeId, field: field);
    final version = (_versions[key] ?? 0) + 1;
    _versions[key] = version;
    final otherVersions = <PlaceStateField, int>{
      for (final candidate in PlaceStateField.values)
        if (candidate != field)
          candidate: _versions[(placeId: placeId, field: candidate)] ?? 0,
    };
    final failures = <PlaceStateOperationKey, PlaceStateFailure>{
      ...before.failures,
    }..remove(key);
    state = PlaceStateControllerSnapshot(
      states: <String, PlaceState>{...before.states, placeId: next},
      pendingKeys: <PlaceStateOperationKey>{...before.pendingKeys, key},
      failures: failures,
    );

    try {
      final repository = ref.read(placeStateRepositoryProvider);
      switch (field) {
        case PlaceStateField.saved:
          await repository.setSaved(uid, placeId, next.saved);
        case PlaceStateField.favorite:
          await repository.setFavorite(uid, placeId, next.favorite);
        case PlaceStateField.liked:
          await repository.setLiked(uid, placeId, next.liked);
      }
      if (_isCurrent(uid, identityGeneration, key, version)) {
        state = PlaceStateControllerSnapshot(
          states: state.states,
          pendingKeys: <PlaceStateOperationKey>{...state.pendingKeys}
            ..remove(key),
          failures: state.failures,
        );
      }
    } catch (error) {
      if (!_isCurrent(uid, identityGeneration, key, version)) return;
      final failure = PlaceStateFailure(
        field: field,
        message: _failureMessage(field),
        cause: error,
      );
      final currentSnapshot = state;
      final currentState = currentSnapshot.states[placeId] ?? next;
      final rolledBack = _restoreField(
        current: currentState,
        base: base,
        field: field,
      );
      final pendingKeys = <PlaceStateOperationKey>{
        ...currentSnapshot.pendingKeys,
      }..remove(key);
      final failures = <PlaceStateOperationKey, PlaceStateFailure>{
        ...currentSnapshot.failures,
        key: failure,
      };
      final hadOtherPlaceActivity =
          before.hasPending(placeId) ||
          otherVersions.entries.any(
            (entry) =>
                (_versions[(placeId: placeId, field: entry.key)] ?? 0) >
                entry.value,
          );
      final priorState = before.states[placeId];
      final canReusePriorMap =
          !hadOtherPlaceActivity &&
          (priorState == null || _sameState(priorState, rolledBack));
      if (canReusePriorMap) {
        state = PlaceStateControllerSnapshot.exact(
          states: before.states,
          pendingKeys: pendingKeys,
          failures: failures,
        );
      } else {
        state = PlaceStateControllerSnapshot(
          states: <String, PlaceState>{
            ...currentSnapshot.states,
            placeId: rolledBack,
          },
          pendingKeys: pendingKeys,
          failures: failures,
        );
      }
      throw failure;
    }
  }

  bool _isCurrent(
    String uid,
    int identityGeneration,
    PlaceStateOperationKey key,
    int version,
  ) {
    return _activeUid == uid &&
        ref.read(currentUidProvider) == uid &&
        _identityGeneration == identityGeneration &&
        _versions[key] == version;
  }

  PlaceState _restoreField({
    required PlaceState current,
    required PlaceState base,
    required PlaceStateField field,
  }) => switch (field) {
    PlaceStateField.saved => PlaceState(
      placeId: current.placeId,
      saved: base.saved,
      savedAt: base.savedAt,
      favorite: current.favorite,
      favoriteAt: current.favoriteAt,
      liked: current.liked,
      likedAt: current.likedAt,
      note: current.note,
      updatedAt: current.updatedAt,
    ),
    PlaceStateField.favorite => PlaceState(
      placeId: current.placeId,
      saved: current.saved,
      savedAt: current.savedAt,
      favorite: base.favorite,
      favoriteAt: base.favoriteAt,
      liked: current.liked,
      likedAt: current.likedAt,
      note: current.note,
      updatedAt: current.updatedAt,
    ),
    PlaceStateField.liked => PlaceState(
      placeId: current.placeId,
      saved: current.saved,
      savedAt: current.savedAt,
      favorite: current.favorite,
      favoriteAt: current.favoriteAt,
      liked: base.liked,
      likedAt: base.likedAt,
      note: current.note,
      updatedAt: current.updatedAt,
    ),
  };

  bool _sameState(PlaceState left, PlaceState right) =>
      left.placeId == right.placeId &&
      left.saved == right.saved &&
      left.savedAt == right.savedAt &&
      left.favorite == right.favorite &&
      left.favoriteAt == right.favoriteAt &&
      left.liked == right.liked &&
      left.likedAt == right.likedAt &&
      left.note == right.note &&
      left.updatedAt == right.updatedAt;

  String _failureMessage(PlaceStateField field) => switch (field) {
    PlaceStateField.saved => 'Impossibile aggiornare le gelaterie salvate.',
    PlaceStateField.favorite =>
      'Impossibile aggiornare la gelateria preferita.',
    PlaceStateField.liked => 'Impossibile aggiornare il Mi piace.',
  };
}

final class _UnauthenticatedPlaceStateCause {
  const _UnauthenticatedPlaceStateCause();
}
