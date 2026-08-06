import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_aggregate.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_aggregate_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/repositories/place_state_repository.dart';
import 'package:gelatino/screens/place_detail_screen.dart';
import 'package:gelatino/widgets/semantic_state_button.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final viewport in <({Size size, String layout, double ratio})>[
    (size: const Size(390, 844), layout: 'compact', ratio: 4 / 3),
    (size: const Size(768, 1024), layout: 'medium', ratio: 4 / 3),
    (size: const Size(1024, 900), layout: 'wide', ratio: 16 / 9),
    (size: const Size(1440, 1000), layout: 'wide', ratio: 16 / 9),
  ]) {
    testWidgets(
      '${viewport.size.width.toInt()} keeps ${viewport.layout} shell and hero ratio while catalog loads',
      (tester) async {
        final loadingCatalog = StreamController<List<Place>>();
        addTearDown(loadingCatalog.close);
        await _pumpDetail(
          tester,
          size: viewport.size,
          catalog: loadingCatalog.stream,
          settle: false,
        );

        final layoutKey = ValueKey<String>(
          'place-detail-${viewport.layout}-layout',
        );
        expect(find.byKey(layoutKey), findsOneWidget);
        expect(
          find.byKey(const ValueKey('place-detail-metadata')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('place-detail-actions')),
          findsOneWidget,
        );
        final loadingHero = tester.getSize(
          find.byKey(const ValueKey('place-detail-hero')),
        );
        expect(
          loadingHero.width / loadingHero.height,
          closeTo(viewport.ratio, 0.01),
        );

        await _pumpDetail(tester, size: viewport.size);

        expect(find.byKey(layoutKey), findsOneWidget);
        expect(
          find.byKey(const ValueKey('place-detail-metadata')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('place-detail-actions')),
          findsOneWidget,
        );
        final hero = tester.getSize(
          find.byKey(const ValueKey('place-detail-hero')),
        );
        expect(hero.width / hero.height, closeTo(viewport.ratio, 0.01));
        final title = tester.getRect(find.text('Gelateria Aurora'));
        final address = tester.getRect(find.text('Via Fragola 1'));
        expect(address.top - title.bottom, greaterThanOrEqualTo(8));
        expect(
          find.bySemanticsLabel(
            'Illustrazione editoriale per Gelateria Aurora',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rating and count come from aggregate with loading error and zero',
    (tester) async {
      await _pumpDetail(
        tester,
        aggregate: const AsyncLoading<PlaceAggregate?>(),
        settle: false,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('place-aggregate-loading')))
            .height,
        greaterThanOrEqualTo(44),
      );

      await _pumpDetail(
        tester,
        aggregate: AsyncError<PlaceAggregate?>(
          StateError('offline'),
          StackTrace.empty,
        ),
      );
      expect(find.text('Riprova valutazioni'), findsOneWidget);

      await _pumpDetail(
        tester,
        aggregate: AsyncData<PlaceAggregate?>(
          PlaceAggregate(
            placeId: 'place-1',
            checkInCount: 0,
            ratingSum: 0,
            ratingAverage: 0,
            updatedAt: DateTime(2026, 7, 15),
          ),
        ),
      );
      expect(find.text('Nessuna valutazione'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      await _pumpDetail(tester);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    },
  );

  test('detail source uses aggregate only and exact external coordinates', () {
    final source = File(
      'lib/screens/place_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains('placeAggregateProvider(placeId)'));
    expect(source, isNot(contains('timelineProvider')));
    expect(source, isNot(contains('CheckIn')));
    expect(
      buildExternalMapUri(_place).toString(),
      'https://www.google.com/maps/search/?api=1&query=45.123456%2C9.987654',
    );
  });

  testWidgets('personal note comes only from current PlaceState', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      state: _personalState(note: 'Cono al pistacchio'),
    );

    expect(find.text('La tua nota'), findsOneWidget);
    expect(find.text('Cono al pistacchio'), findsOneWidget);

    await _pumpDetail(tester, state: const AsyncData<PlaceState?>(null));
    expect(find.text('Cono al pistacchio'), findsNothing);
  });

  testWidgets('save and favorite expose selected semantics and field pending', (
    tester,
  ) async {
    final repository = _RecordingStateRepository()
      ..savedPending = Completer<void>();
    await _pumpDetail(
      tester,
      state: _personalState(saved: true, favorite: true),
      repository: repository,
    );
    final save = find.byKey(const ValueKey('place-save-action'));
    final favorite = find.byKey(const ValueKey('place-favorite-action'));

    expect(
      tester.getSemantics(save).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(favorite).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(favorite).height, greaterThanOrEqualTo(44));

    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<SemanticStateButton>(save).onPressed, isNull);
    expect(tester.widget<SemanticStateButton>(favorite).onPressed, isNotNull);

    repository.savedPending!.complete();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaceDetailScreen)),
    );
    container
        .read(_remotePersonalStateProvider.notifier)
        .emit(_personalState(saved: false, favorite: true));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(save).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    expect(
      tester.getSemantics(favorite).flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('pending save preserves merged remote favorite liked and note', (
    tester,
  ) async {
    final repository = _RecordingStateRepository()
      ..savedPending = Completer<void>();
    await _pumpDetail(
      tester,
      state: _personalState(note: 'Nota precedente'),
      repository: repository,
    );
    final save = find.byKey(const ValueKey('place-save-action'));
    final favorite = find.byKey(const ValueKey('place-favorite-action'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaceDetailScreen)),
    );

    await tester.tap(save);
    await tester.pump();
    container
        .read(_remotePersonalStateProvider.notifier)
        .emit(
          _personalState(
            saved: true,
            favorite: true,
            liked: true,
            note: 'Nota remota concorrente',
          ),
        );
    await tester.pump();

    expect(
      tester.getSemantics(save).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.widget<SemanticStateButton>(save).onPressed, isNull);
    expect(
      tester.getSemantics(favorite).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('Nota remota concorrente'), findsOneWidget);
    expect(find.text('Nota precedente'), findsNothing);
    expect(
      container.read(placeStateProvider('place-1')).requireValue?.liked,
      isTrue,
    );

    container
        .read(_remotePersonalStateProvider.notifier)
        .emit(
          _personalState(
            saved: true,
            favorite: true,
            liked: true,
            note: 'Nota remota concorrente',
          ),
        );
    repository.savedPending!.complete();
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(save).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(favorite).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('Nota remota concorrente'), findsOneWidget);
    expect(
      container.read(placeStateProvider('place-1')).requireValue?.liked,
      isTrue,
    );
  });

  testWidgets('field failure stays inline with its initiating action', (
    tester,
  ) async {
    final repository = _RecordingStateRepository()
      ..savedFailure = StateError('offline');
    await _pumpDetail(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('place-save-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossibile aggiornare le gelaterie salvate.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('place-favorite-error')), findsNothing);
  });

  testWidgets('check-in route carries the decoded encoded place id', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: <RouteBase>[
        GoRoute(
          path: '/detail',
          builder: (_, _) => const PlaceDetailScreen(placeId: 'place one'),
        ),
        GoRoute(
          path: '/check-in',
          builder: (_, state) =>
              Text('Check-in ${state.uri.queryParameters['placeId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpDetail(
      tester,
      place: _copyPlace(id: 'place one'),
      router: router,
    );

    await tester.tap(find.byKey(const ValueKey('place-check-in-action')));
    await tester.pumpAndSettle();

    expect(find.text('Check-in place one'), findsOneWidget);
  });

  testWidgets('catalog error and missing place are explicit and recoverable', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      catalog: Stream<List<Place>>.error(StateError('offline')),
    );
    expect(find.text('Riprova gelateria'), findsOneWidget);

    await _pumpDetail(tester, catalog: Stream.value(const <Place>[]));
    expect(find.text('Gelateria non trovata'), findsOneWidget);
    expect(find.text('Torna alle gelaterie'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Place place = _place,
  Stream<List<Place>>? catalog,
  AsyncValue<PlaceAggregate?>? aggregate,
  AsyncValue<PlaceState?>? state,
  PlaceStateRepository? repository,
  GoRouter? router,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = [
    currentUidProvider.overrideWithValue('alice'),
    placesProvider.overrideWith(
      (ref) => catalog ?? Stream.value(<Place>[place]),
    ),
    placeAggregateProvider.overrideWith(
      (ref, _) => aggregate ?? AsyncData<PlaceAggregate?>(_aggregate),
    ),
    _remotePersonalStateProvider.overrideWith(
      () => _RemotePersonalState(state ?? _personalState()),
    ),
    placeStateProvider.overrideWith(
      (ref, _) => ref.watch(_remotePersonalStateProvider),
    ),
    if (repository != null)
      placeStateRepositoryProvider.overrideWithValue(repository),
  ];
  final home = router == null ? PlaceDetailScreen(placeId: place.id) : null;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: router == null
          ? MaterialApp(home: home)
          : MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

final _remotePersonalStateProvider =
    NotifierProvider<_RemotePersonalState, AsyncValue<PlaceState?>>(
      _RemotePersonalState.new,
    );

final class _RemotePersonalState extends Notifier<AsyncValue<PlaceState?>> {
  _RemotePersonalState([this.initial]);

  final AsyncValue<PlaceState?>? initial;

  @override
  AsyncValue<PlaceState?> build() => initial ?? _personalState();

  void emit(AsyncValue<PlaceState?> value) => state = value;
}

const _place = Place(
  id: 'place-1',
  name: 'Gelateria Aurora',
  address: 'Via Fragola 1',
  location: GeoPoint(45.123456, 9.987654),
  geohash: 'u0nd9',
  createdAt: _FakeDateTime(),
  addedByUid: 'alice',
);

const _aggregate = PlaceAggregate(
  placeId: 'place-1',
  checkInCount: 8,
  ratingSum: 36,
  ratingAverage: 4.5,
  updatedAt: _FakeDateTime(),
);

final class _FakeDateTime implements DateTime {
  const _FakeDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Place _copyPlace({required String id}) => Place(
  id: id,
  name: _place.name,
  address: _place.address,
  location: _place.location,
  geohash: _place.geohash,
  createdAt: DateTime(2026, 7, 15),
  addedByUid: _place.addedByUid,
);

AsyncData<PlaceState?> _personalState({
  bool saved = false,
  bool favorite = false,
  bool liked = false,
  String? note,
}) => AsyncData<PlaceState?>(
  PlaceState(
    placeId: 'place-1',
    saved: saved,
    savedAt: null,
    favorite: favorite,
    favoriteAt: null,
    liked: liked,
    likedAt: null,
    note: note,
    updatedAt: null,
  ),
);

final class _RecordingStateRepository implements PlaceStateRepository {
  Completer<void>? savedPending;
  Object? savedFailure;

  @override
  Future<void> setSaved(String uid, String placeId, bool value) async {
    await savedPending?.future;
    if (savedFailure case final failure?) throw failure;
  }

  @override
  Future<void> setFavorite(String uid, String placeId, bool value) async {}

  @override
  Future<void> setLiked(String uid, String placeId, bool value) async {}

  @override
  Future<void> setNote(String uid, String placeId, String? note) async {}

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) =>
      Stream.value(PlaceState.empty(placeId));

  @override
  Stream<List<PlaceState>> watchSaved(String uid) => const Stream.empty();

  @override
  Stream<List<PlaceState>> watchFavorites(String uid) => const Stream.empty();

  @override
  Stream<List<PlaceState>> watchLiked(String uid) => const Stream.empty();
}
