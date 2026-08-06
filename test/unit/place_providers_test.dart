import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/repositories/place_state_repository.dart';

void main() {
  test(
    'saved favorite and liked join exact deduplicated catalog IDs',
    () async {
      final states = FakePlaceStateRepository()
        ..saved = <PlaceState>[
          state('c', saved: true),
          state('missing', saved: true),
          state('c', saved: true),
          state('a', saved: true),
        ]
        ..favorites = <PlaceState>[
          state('b', favorite: true),
          state('a', favorite: true),
        ]
        ..liked = <PlaceState>[
          state('a', liked: true),
          state('b', liked: true),
        ];
      final places = FakePlaceRepository(<String, Place>{
        'a': place('a'),
        'b': place('b'),
        'c': place('c'),
      });
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placeStateRepositoryProvider.overrideWithValue(states),
          placeRepositoryProvider.overrideWithValue(places),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(
          savedPlacesForUidProvider('alice'),
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(
          favoritePlacesForUidProvider('alice'),
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(
          likedPlacesForUidProvider('alice'),
          (_, _) {},
          fireImmediately: true,
        ),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });

      final saved = await container.read(
        savedPlacesForUidProvider('alice').future,
      );
      final favorites = await container.read(
        favoritePlacesForUidProvider('alice').future,
      );
      final liked = await container.read(
        likedPlacesForUidProvider('alice').future,
      );

      expect(saved.map((item) => item.id), <String>['c', 'a']);
      expect(favorites.map((item) => item.id), <String>['b', 'a']);
      expect(liked.map((item) => item.id), <String>['a', 'b']);
      expect(places.requestedIds, <List<String>>[
        <String>['c', 'missing', 'a'],
        <String>['b', 'a'],
        <String>['a', 'b'],
      ]);
      expect(states.savedWatchUids, <String>['alice']);
      expect(states.favoriteWatchUids, <String>['alice']);
      expect(states.likedWatchUids, <String>['alice']);
    },
  );

  test('signed-out collection facades are empty without private reads', () {
    final states = FakePlaceStateRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(null),
        placeStateRepositoryProvider.overrideWithValue(states),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository(const <String, Place>{}),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(savedPlacesProvider).value, isEmpty);
    expect(container.read(favoritePlacesProvider).value, isEmpty);
    expect(container.read(likedPlacesProvider).value, isEmpty);
    expect(states.savedWatchUids, isEmpty);
    expect(states.favoriteWatchUids, isEmpty);
    expect(states.likedWatchUids, isEmpty);
  });

  test(
    'place state filter subscribes only to the selected private query',
    () async {
      final states = FakePlaceStateRepository()
        ..liked = <PlaceState>[state('liked-place', liked: true)];
      final places = FakePlaceRepository(<String, Place>{
        'liked-place': place('liked-place'),
      });
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placeStateRepositoryProvider.overrideWithValue(states),
          placeRepositoryProvider.overrideWithValue(places),
        ],
      );
      addTearDown(container.dispose);

      for (final filter in <String>['all', 'mine']) {
        final subscription = container.listen(
          placesForStateFilterProvider(filter),
          (_, _) {},
          fireImmediately: true,
        );
        expect(
          container.read(placesForStateFilterProvider(filter)).value,
          isEmpty,
        );
        subscription.close();
      }
      expect(states.savedWatchUids, isEmpty);
      expect(states.favoriteWatchUids, isEmpty);
      expect(states.likedWatchUids, isEmpty);

      final likedSubscription = container.listen(
        placesForStateFilterProvider('liked'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(likedSubscription.close);
      await container.pump();
      await container.pump();

      expect(
        container.read(placesForStateFilterProvider('liked')).value?.single.id,
        'liked-place',
      );
      expect(states.likedWatchUids, <String>['alice']);
      expect(states.savedWatchUids, isEmpty);
      expect(states.favoriteWatchUids, isEmpty);
    },
  );

  test(
    'auth switch disposes raw UID state and ignores stale join completion',
    () async {
      final states = ControlledPlaceStateRepository();
      final places = ControlledPlaceRepository();
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placeStateRepositoryProvider.overrideWithValue(states),
          placeRepositoryProvider.overrideWithValue(places),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        savedPlacesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      states.emitSaved('alice', <PlaceState>[
        state('alice-place', saved: true),
      ]);
      await places.firstRead.future;

      container.updateOverrides([
        currentUidProvider.overrideWithValue('bob'),
        placeStateRepositoryProvider.overrideWithValue(states),
        placeRepositoryProvider.overrideWithValue(places),
      ]);
      await container.pump();
      expect(container.read(savedPlacesProvider).isLoading, isTrue);
      expect(states.activeSavedUids, <String>{'bob'});
      expect(states.cancelledSavedUids, contains('alice'));
      expect(
        container.exists(savedPlaceStatesForUidProvider('alice')),
        isFalse,
      );
      expect(container.exists(savedPlacesForUidProvider('alice')), isFalse);

      places.completeRead('alice-place', <Place>[place('alice-place')]);
      await container.pump();
      expect(container.read(savedPlacesProvider).value, isNull);

      states.emitSaved('bob', <PlaceState>[state('bob-place', saved: true)]);
      await places.nextRead.future;
      places.completeRead('bob-place', <Place>[place('bob-place')]);
      await container.pump();
      expect(
        container.read(savedPlacesProvider).value?.map((item) => item.id),
        <String>['bob-place'],
      );
    },
  );

  test(
    'auth switch disposes saved favorite liked and direct raw state',
    () async {
      final states = ControlledPlaceStateRepository();
      final places = FakePlaceRepository(const <String, Place>{});
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placeStateRepositoryProvider.overrideWithValue(states),
          placeRepositoryProvider.overrideWithValue(places),
        ],
      );
      addTearDown(container.dispose);
      final subscriptions = [
        container.listen(savedPlacesProvider, (_, _) {}, fireImmediately: true),
        container.listen(
          favoritePlacesProvider,
          (_, _) {},
          fireImmediately: true,
        ),
        container.listen(likedPlacesProvider, (_, _) {}, fireImmediately: true),
        container.listen(
          placeStateProvider('place-1'),
          (_, _) {},
          fireImmediately: true,
        ),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });
      expect(states.activeSavedUids, <String>{'alice'});
      expect(states.activeFavoriteUids, <String>{'alice'});
      expect(states.activeLikedUids, <String>{'alice'});
      expect(states.activeDirectKeys, <String>{'alice/place-1'});

      container.updateOverrides([
        currentUidProvider.overrideWithValue('bob'),
        placeStateRepositoryProvider.overrideWithValue(states),
        placeRepositoryProvider.overrideWithValue(places),
      ]);
      await container.pump();

      expect(states.activeSavedUids, <String>{'bob'});
      expect(states.activeFavoriteUids, <String>{'bob'});
      expect(states.activeLikedUids, <String>{'bob'});
      expect(states.activeDirectKeys, <String>{'bob/place-1'});
      expect(states.cancelledSavedUids, contains('alice'));
      expect(states.cancelledFavoriteUids, contains('alice'));
      expect(states.cancelledLikedUids, contains('alice'));
      expect(states.cancelledDirectKeys, contains('alice/place-1'));
      expect(
        container.exists(savedPlaceStatesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(favoritePlaceStatesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(likedPlaceStatesForUidProvider('alice')),
        isFalse,
      );
      expect(
        container.exists(
          placeStateForUidProvider((uid: 'alice', placeId: 'place-1')),
        ),
        isFalse,
      );
    },
  );

  test('optimistic state is visible before persistence succeeds', () async {
    final repository = ControlledPlaceStateRepository();
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      placeStateControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(placeStateControllerProvider.notifier);

    final pending = notifier.toggleSaved('place-1', current: state('place-1'));

    expect(
      container.read(placeStateControllerProvider).states['place-1']?.saved,
      isTrue,
    );
    expect(repository.writeCalls.single, ('alice', 'place-1', 'saved', true));
    expect(repository.pendingWrites, hasLength(1));
    repository.completeWrite(0);
    await pending;
    expect(container.read(placeStateControllerProvider).failure, isNull);
    expect(container.read(placeStateControllerProvider).pendingKeys, isEmpty);
  });

  test('completed optimism yields back to the direct remote state', () async {
    final repository = ControlledPlaceStateRepository();
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final stateSubscription = container.listen(
      placeStateProvider('place-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(stateSubscription.close);
    repository.emitDirect('alice', state('place-1'));
    await container.pump();
    final notifier = container.read(placeStateControllerProvider.notifier);

    final pending = notifier.toggleSaved(
      'place-1',
      current: container.read(placeStateProvider('place-1')).value,
    );
    expect(container.read(placeStateProvider('place-1')).value?.saved, isTrue);

    repository.completeWrite(0);
    await pending;
    await container.pump();
    expect(container.read(placeStateProvider('place-1')).value?.saved, isFalse);
  });

  test(
    'pending saved merges concurrent canonical favorite liked and note updates',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateProvider('place-1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      repository.emitDirect('alice', state('place-1', note: 'Nota precedente'));
      await container.pump();
      final notifier = container.read(placeStateControllerProvider.notifier);

      final pending = notifier.toggleSaved(
        'place-1',
        current: container.read(placeStateProvider('place-1')).requireValue,
      );
      repository.emitDirect(
        'alice',
        state('place-1', favorite: true, liked: true, note: 'Nota concorrente'),
      );
      await container.pump();
      await container.pump();

      final rawCanonical = container
          .read(placeStateForUidProvider((uid: 'alice', placeId: 'place-1')))
          .requireValue!;
      expect(rawCanonical.favorite, isTrue);
      expect(rawCanonical.liked, isTrue);
      expect(rawCanonical.note, 'Nota concorrente');

      final merged = container
          .read(placeStateProvider('place-1'))
          .requireValue!;
      expect(merged.saved, isTrue);
      expect(merged.favorite, isTrue);
      expect(merged.liked, isTrue);
      expect(merged.note, 'Nota concorrente');

      repository.emitDirect(
        'alice',
        state(
          'place-1',
          saved: true,
          favorite: true,
          liked: true,
          note: 'Nota concorrente',
        ),
      );
      repository.completeWrite(0);
      await pending;
      await container.pump();
      await container.pump();

      final canonical = container
          .read(placeStateProvider('place-1'))
          .requireValue!;
      expect(canonical.saved, isTrue);
      expect(canonical.favorite, isTrue);
      expect(canonical.liked, isTrue);
      expect(canonical.note, 'Nota concorrente');
    },
  );

  test(
    'a settled toggle does not override a fresher remote snapshot',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);

      final first = notifier.toggleSaved('place-1', current: state('place-1'));
      repository.completeWrite(0);
      await first;

      final freshRemote = state('place-1', saved: false, favorite: true);
      final second = notifier.toggleSaved('place-1', current: freshRemote);

      expect(repository.writeCalls[1], ('alice', 'place-1', 'saved', true));
      repository.completeWrite(1);
      await second;
    },
  );

  test('unauthenticated failure retains the initiating field', () async {
    final repository = ControlledPlaceStateRepository();
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue(null),
        placeStateRepositoryProvider.overrideWithValue(repository),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository(const <String, Place>{}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(placeStateControllerProvider.notifier);

    await expectLater(
      notifier.toggleFavorite('place-1', current: state('place-1')),
      throwsA(
        isA<PlaceStateFailure>().having(
          (failure) => failure.field,
          'field',
          PlaceStateField.favorite,
        ),
      ),
    );
    await expectLater(
      notifier.toggleLiked('place-1', current: state('place-1')),
      throwsA(
        isA<PlaceStateFailure>().having(
          (failure) => failure.field,
          'field',
          PlaceStateField.liked,
        ),
      ),
    );
    expect(repository.writeCalls, isEmpty);
  });

  test(
    'failed optimistic toggle restores exact prior map and Italian failure',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);
      final before = container.read(placeStateControllerProvider);

      final pending = notifier.toggleFavorite(
        'place-1',
        current: state('place-1', saved: true, note: 'Fuori'),
      );
      expect(
        container
            .read(placeStateControllerProvider)
            .states['place-1']
            ?.favorite,
        isTrue,
      );
      repository.failWrite(0, StateError('offline'));

      await expectLater(pending, throwsA(isA<PlaceStateFailure>()));
      final after = container.read(placeStateControllerProvider);
      expect(identical(after.states, before.states), isTrue);
      expect(after.failure, isA<PlaceStateFailure>());
      expect(after.failure?.message, contains('preferita'));
    },
  );

  test(
    'failures remain isolated by place and field until that retry',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);

      final savedOne = expectLater(
        notifier.toggleSaved('place-1', current: state('place-1')),
        throwsA(isA<PlaceStateFailure>()),
      );
      final favoriteOne = expectLater(
        notifier.toggleFavorite(
          'place-1',
          current: container
              .read(placeStateControllerProvider)
              .states['place-1'],
        ),
        throwsA(isA<PlaceStateFailure>()),
      );
      final savedTwo = expectLater(
        notifier.toggleSaved('place-2', current: state('place-2')),
        throwsA(isA<PlaceStateFailure>()),
      );
      repository.failWrite(0, StateError('saved one failed'));
      repository.failWrite(1, StateError('favorite one failed'));
      repository.failWrite(2, StateError('saved two failed'));
      await Future.wait(<Future<void>>[savedOne, favoriteOne, savedTwo]);

      var snapshot = container.read(placeStateControllerProvider);
      expect(snapshot.failureFor('place-1', PlaceStateField.saved), isNotNull);
      expect(
        snapshot.failureFor('place-1', PlaceStateField.favorite),
        isNotNull,
      );
      expect(snapshot.failureFor('place-2', PlaceStateField.saved), isNotNull);

      final retry = notifier.toggleSaved('place-1', current: state('place-1'));
      snapshot = container.read(placeStateControllerProvider);
      expect(snapshot.failureFor('place-1', PlaceStateField.saved), isNull);
      expect(
        snapshot.failureFor('place-1', PlaceStateField.favorite),
        isNotNull,
      );
      expect(snapshot.failureFor('place-2', PlaceStateField.saved), isNotNull);
      repository.completeWrite(3);
      await retry;
    },
  );

  test('out-of-order completion is latest-wins per place and field', () async {
    final repository = ControlledPlaceStateRepository();
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      placeStateControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(placeStateControllerProvider.notifier);

    final first = notifier.toggleSaved('place-1', current: state('place-1'));
    final second = notifier.toggleSaved(
      'place-1',
      current: container.read(placeStateControllerProvider).states['place-1'],
    );
    expect(
      container.read(placeStateControllerProvider).states['place-1']?.saved,
      isFalse,
    );

    repository.completeWrite(1);
    await second;
    repository.failWrite(0, StateError('older failed'));
    await first;

    final result = container.read(placeStateControllerProvider);
    expect(result.states['place-1']?.saved, isFalse);
    expect(result.failure, isNull);
  });

  test(
    'latest failure after stale success clears the superseded pending key',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateProvider('place-1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      repository.emitDirect('alice', state('place-1'));
      await container.pump();
      final notifier = container.read(placeStateControllerProvider.notifier);

      final first = notifier.toggleSaved(
        'place-1',
        current: container.read(placeStateProvider('place-1')).value,
      );
      final second = notifier.toggleSaved(
        'place-1',
        current: container.read(placeStateControllerProvider).states['place-1'],
      );

      repository.completeWrite(0);
      await first;
      repository.failWrite(1, StateError('latest failed'));
      await expectLater(second, throwsA(isA<PlaceStateFailure>()));
      await container.pump();

      expect(container.read(placeStateControllerProvider).pendingKeys, isEmpty);
      expect(container.read(placeStateProvider('place-1')).value?.saved, false);
    },
  );

  test('different fields do not supersede each other', () async {
    final repository = ControlledPlaceStateRepository();
    final container = controllerContainer(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      placeStateControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final notifier = container.read(placeStateControllerProvider.notifier);

    final saved = notifier.toggleSaved('place-1', current: state('place-1'));
    final favorite = notifier.toggleFavorite(
      'place-1',
      current: container.read(placeStateControllerProvider).states['place-1'],
    );
    repository.completeWrite(1);
    repository.failWrite(0, StateError('saved failed'));

    await favorite;
    await expectLater(saved, throwsA(isA<PlaceStateFailure>()));
    final result = container.read(placeStateControllerProvider);
    expect(result.states['place-1']?.saved, isFalse);
    expect(result.states['place-1']?.favorite, isTrue);
  });

  test(
    'saved then favorite double failure rolls back each field locally',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);
      final savedAt = DateTime.utc(2026, 7, 1);
      final favoriteAt = DateTime.utc(2026, 7, 2);
      final likedAt = DateTime.utc(2026, 7, 3);
      final initial = state(
        'place-1',
        saved: true,
        savedAt: savedAt,
        favorite: true,
        favoriteAt: favoriteAt,
        liked: true,
        likedAt: likedAt,
        note: 'Fuori',
      );

      final saved = notifier.toggleSaved('place-1', current: initial);
      final favorite = notifier.toggleFavorite(
        'place-1',
        current: container.read(placeStateControllerProvider).states['place-1'],
      );
      repository.failWrite(0, StateError('saved failed'));
      await expectLater(saved, throwsA(isA<PlaceStateFailure>()));
      repository.failWrite(1, StateError('favorite failed'));
      await expectLater(favorite, throwsA(isA<PlaceStateFailure>()));

      final result = container.read(placeStateControllerProvider);
      final rolledBack = result.states['place-1'];
      expect(result.pendingKeys, isEmpty);
      expect(rolledBack?.saved, isTrue);
      expect(rolledBack?.savedAt, savedAt);
      expect(rolledBack?.favorite, isTrue);
      expect(rolledBack?.favoriteAt, favoriteAt);
      expect(rolledBack?.liked, isTrue);
      expect(rolledBack?.likedAt, likedAt);
      expect(rolledBack?.note, 'Fuori');
    },
  );

  test(
    'favorite then saved double failure rolls back each field locally',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);

      final favorite = notifier.toggleFavorite(
        'place-1',
        current: state('place-1'),
      );
      final saved = notifier.toggleSaved(
        'place-1',
        current: container.read(placeStateControllerProvider).states['place-1'],
      );
      repository.failWrite(0, StateError('favorite failed'));
      await expectLater(favorite, throwsA(isA<PlaceStateFailure>()));
      repository.failWrite(1, StateError('saved failed'));
      await expectLater(saved, throwsA(isA<PlaceStateFailure>()));

      final result = container.read(placeStateControllerProvider);
      expect(result.pendingKeys, isEmpty);
      expect(result.states['place-1']?.saved, isFalse);
      expect(result.states['place-1']?.favorite, isFalse);
    },
  );

  test(
    'saved success then favorite failure leaves no stale pending key',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);

      final saved = notifier.toggleSaved('place-1', current: state('place-1'));
      final favorite = notifier.toggleFavorite(
        'place-1',
        current: container.read(placeStateControllerProvider).states['place-1'],
      );
      repository.completeWrite(0);
      await saved;
      repository.failWrite(1, StateError('favorite failed'));
      await expectLater(favorite, throwsA(isA<PlaceStateFailure>()));

      final result = container.read(placeStateControllerProvider);
      expect(result.pendingKeys, isEmpty);
      expect(result.states['place-1']?.saved, isTrue);
      expect(result.states['place-1']?.favorite, isFalse);
    },
  );

  test(
    'favorite success then saved failure leaves no stale pending key',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);

      final favorite = notifier.toggleFavorite(
        'place-1',
        current: state('place-1'),
      );
      final saved = notifier.toggleSaved(
        'place-1',
        current: container.read(placeStateControllerProvider).states['place-1'],
      );
      repository.completeWrite(0);
      await favorite;
      repository.failWrite(1, StateError('saved failed'));
      await expectLater(saved, throwsA(isA<PlaceStateFailure>()));

      final result = container.read(placeStateControllerProvider);
      expect(result.pendingKeys, isEmpty);
      expect(result.states['place-1']?.favorite, isTrue);
      expect(result.states['place-1']?.saved, isFalse);
    },
  );

  test(
    'sign-out clears optimistic state and ignores stale write failure',
    () async {
      final repository = ControlledPlaceStateRepository();
      final container = controllerContainer(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        placeStateControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(placeStateControllerProvider.notifier);
      final pending = notifier.toggleLiked(
        'place-1',
        current: state('place-1'),
      );
      expect(container.read(placeStateControllerProvider).states, isNotEmpty);

      container.updateOverrides([
        currentUidProvider.overrideWithValue(null),
        placeStateRepositoryProvider.overrideWithValue(repository),
        placeRepositoryProvider.overrideWithValue(
          FakePlaceRepository(const <String, Place>{}),
        ),
      ]);
      await container.pump();
      expect(container.read(placeStateControllerProvider).states, isEmpty);

      repository.failWrite(0, StateError('stale alice failure'));
      await pending;
      expect(container.read(placeStateControllerProvider).states, isEmpty);
      expect(container.read(placeStateControllerProvider).failure, isNull);
    },
  );

  test(
    'migrated runtime has no shared arrays singleton bootstrap or Rome fallback',
    () {
      for (final path in <String>[
        'lib/models/place.dart',
        'lib/repositories/place_repository.dart',
        'lib/repositories/place_state_repository.dart',
        'lib/providers/place_providers.dart',
        'lib/providers/flavors_provider.dart',
        'lib/providers/gelato_types_provider.dart',
        'lib/screens/collection_screen.dart',
        'lib/screens/place_detail_screen.dart',
        'lib/screens/places_tab.dart',
        'lib/screens/profile_screen.dart',
        'lib/screens/check_in_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('liked_by_uids')), reason: path);
        expect(source, isNot(contains('favorited_by_uids')), reason: path);
        expect(source, isNot(contains('wishlisted_by_uids')), reason: path);
        expect(
          source,
          isNot(contains('FirebaseFirestore.instance')),
          reason: path,
        );
        expect(source, isNot(contains('bootstrapRomePlaces')), reason: path);
        expect(
          source,
          isNot(contains('bootstrapDefaultFlavors')),
          reason: path,
        );
        expect(source, isNot(contains('41.9028')), reason: path);
        expect(source, isNot(contains('12.4964')), reason: path);
        expect(source, isNot(contains('Geolocator.')), reason: path);
      }
    },
  );
}

ProviderContainer controllerContainer(
  ControlledPlaceStateRepository repository,
) {
  return ProviderContainer(
    overrides: [
      currentUidProvider.overrideWithValue('alice'),
      placeStateRepositoryProvider.overrideWithValue(repository),
      placeRepositoryProvider.overrideWithValue(
        FakePlaceRepository(const <String, Place>{}),
      ),
    ],
  );
}

Place place(String id) => Place(
  id: id,
  name: 'Gelateria $id',
  address: 'Via $id',
  location: const GeoPoint(45, 9),
  geohash: 'u0n',
  createdAt: DateTime(2026, 7, 15),
  addedByUid: 'alice',
);

PlaceState state(
  String placeId, {
  bool saved = false,
  DateTime? savedAt,
  bool favorite = false,
  DateTime? favoriteAt,
  bool liked = false,
  DateTime? likedAt,
  String? note,
}) => PlaceState(
  placeId: placeId,
  saved: saved,
  savedAt: savedAt,
  favorite: favorite,
  favoriteAt: favoriteAt,
  liked: liked,
  likedAt: likedAt,
  note: note,
  updatedAt: null,
);

class FakePlaceRepository implements PlaceRepository {
  FakePlaceRepository(this.catalog);

  final Map<String, Place> catalog;
  final List<List<String>> requestedIds = <List<String>>[];

  @override
  Stream<List<Place>> watchPlaces() =>
      Stream<List<Place>>.value(catalog.values.toList());

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) async {
    requestedIds.add(List<String>.from(placeIds));
    return <Place>[for (final id in placeIds) ?catalog[id]];
  }

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) => throw UnimplementedError();

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) => throw UnimplementedError();
}

class FakePlaceStateRepository implements PlaceStateRepository {
  List<PlaceState> saved = const <PlaceState>[];
  List<PlaceState> favorites = const <PlaceState>[];
  List<PlaceState> liked = const <PlaceState>[];
  final List<String> savedWatchUids = <String>[];
  final List<String> favoriteWatchUids = <String>[];
  final List<String> likedWatchUids = <String>[];

  @override
  Stream<List<PlaceState>> watchSaved(String uid) {
    savedWatchUids.add(uid);
    return Stream<List<PlaceState>>.value(saved);
  }

  @override
  Stream<List<PlaceState>> watchFavorites(String uid) {
    favoriteWatchUids.add(uid);
    return Stream<List<PlaceState>>.value(favorites);
  }

  @override
  Stream<List<PlaceState>> watchLiked(String uid) {
    likedWatchUids.add(uid);
    return Stream<List<PlaceState>>.value(liked);
  }

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) =>
      Stream<PlaceState?>.value(null);

  @override
  Future<void> setFavorite(String uid, String placeId, bool value) async {}

  @override
  Future<void> setLiked(String uid, String placeId, bool value) async {}

  @override
  Future<void> setNote(String uid, String placeId, String? note) async {}

  @override
  Future<void> setSaved(String uid, String placeId, bool value) async {}
}

final class ControlledPlaceStateRepository extends FakePlaceStateRepository {
  final Map<String, StreamController<List<PlaceState>>> savedControllers =
      <String, StreamController<List<PlaceState>>>{};
  final Set<String> activeSavedUids = <String>{};
  final Set<String> activeFavoriteUids = <String>{};
  final Set<String> activeLikedUids = <String>{};
  final Set<String> activeDirectKeys = <String>{};
  final List<String> cancelledSavedUids = <String>[];
  final List<String> cancelledFavoriteUids = <String>[];
  final List<String> cancelledLikedUids = <String>[];
  final List<String> cancelledDirectKeys = <String>[];
  final Map<String, StreamController<List<PlaceState>>> favoriteControllers =
      <String, StreamController<List<PlaceState>>>{};
  final Map<String, StreamController<List<PlaceState>>> likedControllers =
      <String, StreamController<List<PlaceState>>>{};
  final Map<String, StreamController<PlaceState?>> directControllers =
      <String, StreamController<PlaceState?>>{};
  final List<Completer<void>> pendingWrites = <Completer<void>>[];
  final List<(String, String, String, bool)> writeCalls =
      <(String, String, String, bool)>[];

  void emitSaved(String uid, List<PlaceState> states) {
    savedControllers.putIfAbsent(uid, () => _controller(uid)).add(states);
  }

  void emitDirect(String uid, PlaceState? state) {
    final key = '$uid/${state?.placeId ?? 'place-1'}';
    directControllers.putIfAbsent(key, () => _directController(key)).add(state);
  }

  StreamController<List<PlaceState>> _controller(String uid) =>
      StreamController<List<PlaceState>>.broadcast(
        sync: true,
        onListen: () => activeSavedUids.add(uid),
        onCancel: () {
          activeSavedUids.remove(uid);
          cancelledSavedUids.add(uid);
        },
      );

  StreamController<List<PlaceState>> _favoriteController(String uid) =>
      StreamController<List<PlaceState>>.broadcast(
        sync: true,
        onListen: () => activeFavoriteUids.add(uid),
        onCancel: () {
          activeFavoriteUids.remove(uid);
          cancelledFavoriteUids.add(uid);
        },
      );

  StreamController<List<PlaceState>> _likedController(String uid) =>
      StreamController<List<PlaceState>>.broadcast(
        sync: true,
        onListen: () => activeLikedUids.add(uid),
        onCancel: () {
          activeLikedUids.remove(uid);
          cancelledLikedUids.add(uid);
        },
      );

  StreamController<PlaceState?> _directController(String key) =>
      StreamController<PlaceState?>.broadcast(
        sync: true,
        onListen: () => activeDirectKeys.add(key),
        onCancel: () {
          activeDirectKeys.remove(key);
          cancelledDirectKeys.add(key);
        },
      );

  @override
  Stream<List<PlaceState>> watchSaved(String uid) {
    savedWatchUids.add(uid);
    return savedControllers.putIfAbsent(uid, () => _controller(uid)).stream;
  }

  @override
  Stream<List<PlaceState>> watchFavorites(String uid) {
    favoriteWatchUids.add(uid);
    return favoriteControllers
        .putIfAbsent(uid, () => _favoriteController(uid))
        .stream;
  }

  @override
  Stream<List<PlaceState>> watchLiked(String uid) {
    likedWatchUids.add(uid);
    return likedControllers
        .putIfAbsent(uid, () => _likedController(uid))
        .stream;
  }

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) {
    final key = '$uid/$placeId';
    return directControllers
        .putIfAbsent(key, () => _directController(key))
        .stream;
  }

  @override
  Future<void> setSaved(String uid, String placeId, bool value) =>
      _write(uid, placeId, 'saved', value);

  @override
  Future<void> setFavorite(String uid, String placeId, bool value) =>
      _write(uid, placeId, 'favorite', value);

  @override
  Future<void> setLiked(String uid, String placeId, bool value) =>
      _write(uid, placeId, 'liked', value);

  Future<void> _write(String uid, String placeId, String field, bool value) {
    writeCalls.add((uid, placeId, field, value));
    final completer = Completer<void>();
    pendingWrites.add(completer);
    return completer.future;
  }

  void completeWrite(int index) => pendingWrites[index].complete();

  void failWrite(int index, Object error) =>
      pendingWrites[index].completeError(error, StackTrace.current);
}

final class ControlledPlaceRepository extends FakePlaceRepository {
  ControlledPlaceRepository() : super(const <String, Place>{});

  final Completer<List<String>> firstRead = Completer<List<String>>();
  Completer<List<String>> nextRead = Completer<List<String>>();
  final Map<String, Completer<List<Place>>> completions =
      <String, Completer<List<Place>>>{};

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) {
    requestedIds.add(List<String>.from(placeIds));
    final key = placeIds.single;
    final completion = completions[key] ??= Completer<List<Place>>();
    if (!firstRead.isCompleted) {
      firstRead.complete(placeIds);
    } else {
      nextRead.complete(placeIds);
    }
    return completion.future;
  }

  void completeRead(String placeId, List<Place> places) {
    completions[placeId]!.complete(places);
  }
}
