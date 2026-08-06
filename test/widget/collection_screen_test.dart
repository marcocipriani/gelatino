import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/repositories/place_state_repository.dart';
import 'package:gelatino/screens/collection_screen.dart';
import 'package:gelatino/widgets/collection/place_editorial_cover.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('shows the exact editorial header and plural saved count', (
    tester,
  ) async {
    await _pumpCollection(tester, places: _places);

    expect(find.text('La tua collezione'), findsOneWidget);
    expect(find.text('3 gelaterie salvate'), findsOneWidget);
    expect(find.text('Da provare'), findsOneWidget);
  });

  testWidgets('uses the singular saved gelateria count', (tester) async {
    await _pumpCollection(tester, places: <Place>[_places.first]);

    expect(find.text('1 gelateria salvata'), findsOneWidget);
  });

  testWidgets('featured content opens the encoded place route', (tester) async {
    final encodedPlace = _place('roma centro', 'Gelateria Aurora');
    await _pumpCollection(
      tester,
      places: <Place>[encodedPlace, ..._places.skip(1)],
    );

    await tester.tap(find.byKey(const ValueKey('featured-place-content')));
    await tester.pumpAndSettle();

    expect(find.text('Dettaglio roma centro'), findsOneWidget);
  });

  for (final viewport in <({Size size, String layout})>[
    (size: Size(390, 844), layout: 'compact'),
    (size: Size(768, 1024), layout: 'medium'),
    (size: Size(1024, 900), layout: 'wide'),
    (size: Size(1440, 1000), layout: 'wide'),
  ]) {
    testWidgets(
      '${viewport.size.width.toInt()}px uses ${viewport.layout} layout without overflow',
      (tester) async {
        await _pumpCollection(tester, size: viewport.size, places: _places);

        expect(
          find.byKey(ValueKey('collection-${viewport.layout}-layout')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('featured-place-card')),
          findsOneWidget,
        );
        if (viewport.layout == 'wide') {
          final featuredWidth = tester
              .getSize(find.byKey(const ValueKey('featured-place-card')))
              .width;
          final remainingWidth = tester
              .getSize(
                find.byKey(const ValueKey('collection-wide-remaining-grid')),
              )
              .width;
          expect(
            find.byKey(const ValueKey('collection-wide-remaining-grid')),
            findsOneWidget,
          );
          expect(featuredWidth / remainingWidth, greaterThanOrEqualTo(1.5));
        } else {
          expect(
            find.byKey(const ValueKey('collection-remaining-strip')),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('remaining-card-place-2')))
                .width,
            220,
          );
        }
        final featuredCoverSize = tester.getSize(
          find.byKey(const ValueKey('place-editorial-cover-place-1')),
        );
        expect(
          featuredCoverSize.width / featuredCoverSize.height,
          closeTo(16 / 10, 0.01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved control is selected, 44px and single flight per place', (
    tester,
  ) async {
    final repository = _RecordingPlaceStateRepository()
      ..pending = Completer<void>();
    await _pumpCollection(
      tester,
      places: <Place>[_places.first],
      repository: repository,
    );
    final control = find.byKey(const ValueKey('saved-control-place-1'));
    final semantics = tester.getSemantics(control);

    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.label, contains('Gelateria Aurora'));
    expect(tester.getSize(control).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    final initialSize = tester.getSize(control);

    await tester.tap(control);
    await tester.pump();
    await tester.tap(control, warnIfMissed: false);
    await tester.pump();

    expect(repository.savedWrites, <(String, String, bool)>[
      ('alice', 'place-1', false),
    ]);
    expect(tester.getSize(control), initialSize);

    repository.pending!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'favorite and liked pending keep saved enabled while saved pending blocks it',
    (tester) async {
      final repository = _RecordingPlaceStateRepository()
        ..favoritePending = Completer<void>()
        ..likedPending = Completer<void>()
        ..pending = Completer<void>();
      await _pumpCollection(
        tester,
        places: <Place>[_places.first],
        repository: repository,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CollectionScreen)),
      );
      final notifier = container.read(placeStateControllerProvider.notifier);
      final control = find.byKey(const ValueKey('saved-control-place-1'));
      IconButton savedButton() => tester.widget<IconButton>(
        find.descendant(of: control, matching: find.byType(IconButton)),
      );

      final favorite = notifier.toggleFavorite(
        'place-1',
        current: _savedState('place-1'),
      );
      await tester.pump();
      expect(savedButton().onPressed, isNotNull);
      repository.favoritePending!.complete();
      await favorite;
      await tester.pump();

      final liked = notifier.toggleLiked(
        'place-1',
        current: _savedState('place-1'),
      );
      await tester.pump();
      expect(savedButton().onPressed, isNotNull);
      repository.likedPending!.complete();
      await liked;
      await tester.pump();

      final saved = notifier.toggleSaved(
        'place-1',
        current: _savedState('place-1'),
      );
      await tester.pump();
      expect(savedButton().onPressed, isNull);
      repository.pending!.complete();
      await saved;
      await tester.pump();
    },
  );

  testWidgets('failed toggle keeps place selected and shows inline recovery', (
    tester,
  ) async {
    final repository = _RecordingPlaceStateRepository()
      ..failure = StateError('offline');
    await _pumpCollection(tester, places: _places, repository: repository);
    final card = find.byKey(const ValueKey('remaining-card-place-2'));
    final control = find.byKey(const ValueKey('saved-control-place-2'));

    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();

    expect(find.text('Fiordilatte Lab'), findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('Impossibile aggiornare le gelaterie salvate.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Riprova')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(control).flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('failed toggle survives card disposal and remount per place', (
    tester,
  ) async {
    final repository = _RecordingPlaceStateRepository()
      ..pending = Completer<void>()
      ..failure = StateError('offline');
    final router = await _pumpCollection(
      tester,
      places: <Place>[_places.first],
      repository: repository,
    );
    final control = find.byKey(const ValueKey('saved-control-place-1'));

    await tester.tap(control);
    await tester.pump();
    router.go('/places');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-control-place-1')), findsNothing);

    repository.pending!.complete();
    await tester.pumpAndSettle();
    router.go('/collection');
    await tester.pumpAndSettle();

    expect(find.text('Gelateria Aurora'), findsOneWidget);
    expect(
      find.text('Impossibile aggiornare le gelaterie salvate.'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('saved-control-place-1')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  test('collection has one Place boundary and no private media dependency', () {
    final screen = File(
      'lib/screens/collection_screen.dart',
    ).readAsStringSync();
    final cards = File(
      'lib/widgets/collection/saved_place_cards.dart',
    ).readAsStringSync();
    final cover = File(
      'lib/widgets/collection/place_editorial_cover.dart',
    ).readAsStringSync();
    final combined = '$screen\n$cards\n$cover';

    expect(screen, contains('ref.watch(savedPlacesProvider)'));
    expect(screen, isNot(contains('placesProvider')));
    expect(screen, isNot(contains('favoritePlacesProvider')));
    expect(screen, isNot(contains('currentUserProvider')));
    expect(screen, isNot(contains('FlavorsManager')));
    for (final forbidden in <String>[
      'CheckIn',
      'CachedNetworkImage',
      'NetworkImage',
      'firebase_storage',
      'http://',
      'https://',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('editorial cover palette is stable with at least three variants', () {
    expect(
      PlaceEditorialCover.paletteIndexFor('place-stable'),
      PlaceEditorialCover.paletteIndexFor('place-stable'),
    );
    final variants = <int>{
      for (final id in <String>['aurora', 'menta', 'puffo', 'sorbetto', 'roma'])
        PlaceEditorialCover.paletteIndexFor(id),
    };
    expect(variants.length, greaterThanOrEqualTo(3));
  });

  testWidgets('editorial cover semantics never imply a real photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 200,
            child: PlaceEditorialCover(
              placeId: 'aurora',
              placeName: 'Gelateria Aurora',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Illustrazione editoriale per Gelateria Aurora'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('foto', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('loading place state presents saved fallback as selected', (
    tester,
  ) async {
    await _pumpCollection(
      tester,
      places: <Place>[_places.first],
      placeState: const AsyncLoading<PlaceState?>(),
    );

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('saved-control-place-1')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('empty collection explores gelaterie through go', (tester) async {
    await _pumpCollection(tester, places: const <Place>[]);

    expect(find.text('Nessuna gelateria salvata'), findsOneWidget);
    expect(
      find.text('Salva le gelaterie che vuoi provare e le ritroverai qui.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Esplora le gelaterie'));
    await tester.pumpAndSettle();

    expect(find.text('Gelaterie'), findsOneWidget);
  });

  testWidgets('provider error retry refreshes the saved collection', (
    tester,
  ) async {
    var reads = 0;
    await _pumpCollection(
      tester,
      places: const <Place>[],
      savedFactory: () => ++reads == 1
          ? AsyncError<List<Place>>(StateError('offline'), StackTrace.current)
          : const AsyncData<List<Place>>(<Place>[]),
    );

    expect(find.text('Riprova'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();

    expect(reads, greaterThanOrEqualTo(2));
    expect(find.text('Nessuna gelateria salvata'), findsOneWidget);
  });

  for (final viewport in <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 900),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'loading skeleton matches final geometry at ${viewport.width.toInt()}px',
      (tester) async {
        await _pumpCollection(tester, size: viewport, places: _places);
        final finalFeatured = tester.getSize(
          find.byKey(const ValueKey('featured-place-card')),
        );
        final isWide = viewport.width >= 1024;
        final finalRemaining = tester.getSize(
          find.byKey(
            ValueKey(
              isWide
                  ? 'collection-wide-remaining-grid'
                  : 'remaining-card-place-2',
            ),
          ),
        );

        await _pumpCollection(
          tester,
          size: viewport,
          places: const <Place>[],
          savedFactory: () => const AsyncLoading<List<Place>>(),
        );
        final skeletonFeatured = tester.getSize(
          find.byKey(const ValueKey('collection-skeleton-featured')),
        );
        final skeletonRemaining = tester.getSize(
          find.byKey(const ValueKey('collection-skeleton-remaining')),
        );
        final skeletonFeaturedCover = tester.getSize(
          find.byKey(const ValueKey('collection-skeleton-featured-cover')),
        );

        expect(skeletonFeatured.width, closeTo(finalFeatured.width, 0.01));
        expect(skeletonFeatured.height, closeTo(finalFeatured.height, 0.01));
        expect(
          skeletonFeaturedCover.width / skeletonFeaturedCover.height,
          closeTo(16 / 10, 0.01),
        );
        expect(skeletonRemaining.width, closeTo(finalRemaining.width, 0.01));
        expect(skeletonRemaining.height, closeTo(finalRemaining.height, 0.01));
        if (isWide) {
          expect(
            skeletonFeatured.width / skeletonRemaining.width,
            greaterThanOrEqualTo(1.5),
          );
        } else {
          final remainingCover = tester.getSize(
            find.byKey(const ValueKey('collection-skeleton-remaining-cover')),
          );
          expect(
            remainingCover.width / remainingCover.height,
            closeTo(16 / 10, 0.01),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('favorite flavors remain separate and route to their screen', (
    tester,
  ) async {
    await _pumpCollection(tester, places: _places);
    final savedArea = find.byKey(const ValueKey('collection-compact-layout'));
    final flavors = find.byKey(const ValueKey('favorite-flavors-section'));

    await tester.scrollUntilVisible(
      flavors,
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(flavors).dy - tester.getBottomLeft(savedArea).dy,
      greaterThanOrEqualTo(32),
    );
    await tester.tap(find.text('Gusti preferiti'));
    await tester.pumpAndSettle();

    expect(find.text('Gusti preferiti'), findsOneWidget);
  });

  testWidgets('unauthenticated collection offers login explicitly', (
    tester,
  ) async {
    final router = await _pumpCollection(
      tester,
      places: const <Place>[],
      uid: null,
    );

    expect(
      find.text('Accedi per vedere le gelaterie che hai salvato.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('La tua collezione'), findsNothing);
  });
}

Future<GoRouter> _pumpCollection(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  required List<Place> places,
  PlaceStateRepository? repository,
  String? uid = 'alice',
  AsyncValue<List<Place>> Function()? savedFactory,
  AsyncValue<PlaceState?>? placeState,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/collection',
    routes: <RouteBase>[
      GoRoute(
        path: '/collection',
        builder: (context, state) => const CollectionScreen(),
      ),
      GoRoute(
        path: '/place/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Dettaglio ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/places',
        builder: (context, state) => const Scaffold(body: Text('Gelaterie')),
      ),
      GoRoute(
        path: '/favorite-flavors',
        builder: (context, state) =>
            const Scaffold(body: Text('Gusti preferiti')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('Accedi')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        if (savedFactory == null)
          savedPlacesProvider.overrideWithValue(AsyncData<List<Place>>(places))
        else
          savedPlacesProvider.overrideWith((ref) => savedFactory()),
        placeStateProvider.overrideWith(
          (ref, placeId) =>
              placeState ?? AsyncData<PlaceState?>(_savedState(placeId)),
        ),
        if (repository != null)
          placeStateRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

PlaceState _savedState(String id) => PlaceState.empty(id).copyWith(saved: true);

Place _place(String id, String name) => Place(
  id: id,
  name: name,
  address: 'Via del Gelato $id, Roma',
  location: const GeoPoint(41.9, 12.5),
  geohash: 'sr2yk',
  createdAt: DateTime(2026, 7, 15),
  addedByUid: 'editor',
);

final List<Place> _places = <Place>[
  _place('place-1', 'Gelateria Aurora'),
  _place('place-2', 'Fiordilatte Lab'),
  _place('place-3', 'Menta Fredda'),
];

final class _RecordingPlaceStateRepository implements PlaceStateRepository {
  final List<(String, String, bool)> savedWrites = <(String, String, bool)>[];
  Completer<void>? pending;
  Completer<void>? favoritePending;
  Completer<void>? likedPending;
  Object? failure;

  @override
  Future<void> setSaved(String uid, String placeId, bool value) async {
    savedWrites.add((uid, placeId, value));
    await pending?.future;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) =>
      Stream<PlaceState?>.value(_savedState(placeId));

  @override
  Stream<List<PlaceState>> watchSaved(String uid) =>
      const Stream<List<PlaceState>>.empty();

  @override
  Stream<List<PlaceState>> watchFavorites(String uid) =>
      const Stream<List<PlaceState>>.empty();

  @override
  Stream<List<PlaceState>> watchLiked(String uid) =>
      const Stream<List<PlaceState>>.empty();

  @override
  Future<void> setFavorite(String uid, String placeId, bool value) async {
    await favoritePending?.future;
  }

  @override
  Future<void> setLiked(String uid, String placeId, bool value) async {
    await likedPending?.future;
  }

  @override
  Future<void> setNote(String uid, String placeId, String? note) async {}
}
