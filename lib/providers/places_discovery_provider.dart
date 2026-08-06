import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import 'auth_provider.dart';
import 'flavor_search_provider.dart';
import 'place_providers.dart';

enum PlacesFilter {
  all('Tutte'),
  liked('Mi piace'),
  favorites('Preferite'),
  saved('Salvate'),
  addedByMe('Aggiunte da me');

  const PlacesFilter(this.label);

  final String label;
}

enum PlacesViewMode { list, map }

enum PlaceMarkerVariant { favorite, saved, liked, userAdded, standard }

final class PlacesDiscoveryState {
  const PlacesDiscoveryState({
    this.query = '',
    this.filter = PlacesFilter.all,
    this.selectedPlaceId,
    this.viewMode = PlacesViewMode.list,
    this.userExplicitlyChoseView = false,
  });

  final String query;
  final PlacesFilter filter;
  final String? selectedPlaceId;
  final PlacesViewMode viewMode;
  final bool userExplicitlyChoseView;

  PlacesDiscoveryState copyWith({
    String? query,
    PlacesFilter? filter,
    String? selectedPlaceId,
    bool clearSelectedPlace = false,
    PlacesViewMode? viewMode,
    bool? userExplicitlyChoseView,
  }) => PlacesDiscoveryState(
    query: query ?? this.query,
    filter: filter ?? this.filter,
    selectedPlaceId: clearSelectedPlace
        ? null
        : selectedPlaceId ?? this.selectedPlaceId,
    viewMode: viewMode ?? this.viewMode,
    userExplicitlyChoseView:
        userExplicitlyChoseView ?? this.userExplicitlyChoseView,
  );

  @override
  bool operator ==(Object other) =>
      other is PlacesDiscoveryState &&
      other.query == query &&
      other.filter == filter &&
      other.selectedPlaceId == selectedPlaceId &&
      other.viewMode == viewMode &&
      other.userExplicitlyChoseView == userExplicitlyChoseView;

  @override
  int get hashCode => Object.hash(
    query,
    filter,
    selectedPlaceId,
    viewMode,
    userExplicitlyChoseView,
  );
}

final placesDiscoveryControllerProvider =
    NotifierProvider<PlacesDiscoveryController, PlacesDiscoveryState>(
      PlacesDiscoveryController.new,
    );

final class PlacesDiscoveryController extends Notifier<PlacesDiscoveryState> {
  String? _activeUid;
  bool _loadedDefaultApplied = false;

  @override
  PlacesDiscoveryState build() {
    final uid = ref.watch(currentUidProvider);
    if (_activeUid != uid) {
      _activeUid = uid;
      _loadedDefaultApplied = false;
    }
    return const PlacesDiscoveryState();
  }

  void applyLoadedDefault(String? value) {
    if (_loadedDefaultApplied || state.userExplicitlyChoseView) return;
    _loadedDefaultApplied = true;
    state = state.copyWith(
      viewMode: value == 'map' ? PlacesViewMode.map : PlacesViewMode.list,
    );
  }

  void setQuery(String value) => state = state.copyWith(query: value);

  void setFilter(PlacesFilter value) => state = state.copyWith(filter: value);

  void selectPlace(String? placeId) => state = placeId == null
      ? state.copyWith(clearSelectedPlace: true)
      : state.copyWith(selectedPlaceId: placeId);

  void chooseView(PlacesViewMode value) =>
      state = state.copyWith(viewMode: value, userExplicitlyChoseView: true);

  void resetFilters() => state = state.copyWith(
    query: '',
    filter: PlacesFilter.all,
    clearSelectedPlace: true,
  );
}

final class DiscoveryPlace {
  const DiscoveryPlace({
    required this.place,
    this.liked = false,
    this.favorite = false,
    this.saved = false,
    this.flavorMatch,
  });

  final Place place;
  final bool liked;
  final bool favorite;
  final bool saved;
  final FlavorPlaceMatch? flavorMatch;

  DiscoveryPlace copyWith({
    bool? liked,
    bool? favorite,
    bool? saved,
    FlavorPlaceMatch? flavorMatch,
  }) => DiscoveryPlace(
    place: place,
    liked: liked ?? this.liked,
    favorite: favorite ?? this.favorite,
    saved: saved ?? this.saved,
    flavorMatch: flavorMatch ?? this.flavorMatch,
  );
}

final placesDiscoveryDataProvider =
    Provider.autoDispose<AsyncValue<List<DiscoveryPlace>>>((ref) {
      final catalog = ref.watch(placesProvider);
      final liked = ref.watch(likedPlacesProvider);
      final favorites = ref.watch(favoritePlacesProvider);
      final saved = ref.watch(savedPlacesProvider);
      final uid = ref.watch(currentUidProvider);
      final interaction = ref.watch(placesDiscoveryControllerProvider);
      final optimistic = ref.watch(placeStateControllerProvider);

      final inputs = <AsyncValue<Object?>>[catalog, liked, favorites, saved];
      for (final input in inputs) {
        if (input.hasError) {
          return AsyncError<List<DiscoveryPlace>>(
            input.error!,
            input.stackTrace ?? StackTrace.empty,
          );
        }
      }
      if (inputs.any((input) => input.isLoading)) {
        return const AsyncLoading<List<DiscoveryPlace>>();
      }

      final entries = aggregateDiscoveryPlaces(
        catalog: catalog.requireValue,
        liked: liked.requireValue,
        favorites: favorites.requireValue,
        saved: saved.requireValue,
        optimistic: optimistic,
      );
      final flavorMatches = lookupFlavor(
        ref.watch(flavorIndexProvider),
        interaction.query,
      );
      return AsyncData<List<DiscoveryPlace>>(
        filterDiscoveryPlaces(
          entries,
          query: interaction.query,
          filter: interaction.filter,
          currentUid: uid,
          flavorMatches: flavorMatches,
        ),
      );
    }, name: 'placesDiscoveryDataProvider');

List<DiscoveryPlace> aggregateDiscoveryPlaces({
  required List<Place> catalog,
  required List<Place> liked,
  required List<Place> favorites,
  required List<Place> saved,
  PlaceStateControllerSnapshot? optimistic,
}) {
  final likedIds = liked.map((place) => place.id).toSet();
  final favoriteIds = favorites.map((place) => place.id).toSet();
  final savedIds = saved.map((place) => place.id).toSet();
  return List<DiscoveryPlace>.unmodifiable(
    catalog.map((place) {
      var entry = DiscoveryPlace(
        place: place,
        liked: likedIds.contains(place.id),
        favorite: favoriteIds.contains(place.id),
        saved: savedIds.contains(place.id),
      );
      final snapshot = optimistic;
      final state = snapshot?.states[place.id];
      if (state != null) {
        entry = entry.copyWith(
          liked: snapshot!.hasPending(place.id, PlaceStateField.liked)
              ? state.liked
              : null,
          favorite: snapshot.hasPending(place.id, PlaceStateField.favorite)
              ? state.favorite
              : null,
          saved: snapshot.hasPending(place.id, PlaceStateField.saved)
              ? state.saved
              : null,
        );
      }
      return entry;
    }),
  );
}

List<DiscoveryPlace> filterDiscoveryPlaces(
  List<DiscoveryPlace> places, {
  required String query,
  required PlacesFilter filter,
  required String? currentUid,
  Map<String, FlavorPlaceMatch>? flavorMatches,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final flavorHits = <DiscoveryPlace>[];
  final nameHits = <DiscoveryPlace>[];
  for (final entry in places) {
    final place = entry.place;
    final passesFilter = switch (filter) {
      PlacesFilter.all => true,
      PlacesFilter.liked => currentUid != null && entry.liked,
      PlacesFilter.favorites => currentUid != null && entry.favorite,
      PlacesFilter.saved => currentUid != null && entry.saved,
      PlacesFilter.addedByMe =>
        currentUid != null && place.addedByUid == currentUid,
    };
    if (!passesFilter) continue;

    final flavorMatch = flavorMatches?[place.id];
    if (flavorMatch != null) {
      flavorHits.add(entry.copyWith(flavorMatch: flavorMatch));
      continue;
    }

    final matchesQuery =
        normalizedQuery.isEmpty ||
        place.name.toLowerCase().contains(normalizedQuery) ||
        place.address.toLowerCase().contains(normalizedQuery);
    if (matchesQuery) nameHits.add(entry);
  }
  // Stable sort by rating desc: List.sort isn't guaranteed stable, so break
  // ties with the original (catalog) index to keep ordering deterministic.
  final ranked = flavorHits.indexed.toList()
    ..sort((a, b) {
      final byRating = b.$2.flavorMatch!.bestRating.compareTo(
        a.$2.flavorMatch!.bestRating,
      );
      return byRating != 0 ? byRating : a.$1.compareTo(b.$1);
    });
  return List<DiscoveryPlace>.unmodifiable([
    for (final (_, entry) in ranked) entry,
    ...nameHits,
  ]);
}

PlaceMarkerVariant markerVariantFor(
  DiscoveryPlace entry, {
  required String? currentUid,
}) {
  if (entry.favorite) return PlaceMarkerVariant.favorite;
  if (entry.saved) return PlaceMarkerVariant.saved;
  if (entry.liked) return PlaceMarkerVariant.liked;
  if (currentUid != null && entry.place.addedByUid == currentUid) {
    return PlaceMarkerVariant.userAdded;
  }
  return PlaceMarkerVariant.standard;
}
