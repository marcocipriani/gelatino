import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/models/flavor.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/firebase/firebase_providers.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/check_in_flow_provider.dart';
import 'package:gelatino/providers/flavors_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/gelato_types_provider.dart';
import 'package:gelatino/providers/location_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/router_auth_provider.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';
import 'package:gelatino/repositories/check_in_label_repository.dart';
import 'package:gelatino/repositories/check_in_publication_repository.dart';
import 'package:gelatino/repositories/check_in_repository.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/screens/check_in/check_in_flow.dart';
import 'package:gelatino/screens/check_in_screen.dart';
import 'package:gelatino/router.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/authenticated_shell.dart';
import 'package:gelatino/widgets/flavors_manager.dart';
import 'package:gelatino/widgets/gelato_type_selector.dart';
import 'package:gelatino/widgets/places/place_map_surface.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _testUidProvider = NotifierProvider<_TestUidController, String>(
  _TestUidController.new,
);

void main() {
  const checkInId = 'ABCDEFGHIJKLMNOPQRST';
  final now = DateTime.utc(2026, 7, 15, 12);

  CheckInDraft draftAt(
    int step, {
    PendingPlaceDraft? pendingPlace,
    List<String> flavorIds = const <String>['pistacchio'],
    List<String> taggedUserIds = const <String>[],
  }) => CheckInDraft(
    id: checkInId,
    currentStep: step,
    localPhotoName: 'gelato.jpg',
    stagingObjectPath: 'staging/alice/$checkInId.jpg',
    placeId: pendingPlace == null && step >= 2 ? 'place-1' : null,
    pendingPlace: pendingPlace,
    gelatoTypeId: step >= 3 ? 'cono' : null,
    flavorIds: step >= 3 ? flavorIds : const <String>[],
    rating: step >= 4 ? 5 : null,
    reviewText: step >= 4 ? 'Cremoso e bilanciato' : '',
    taggedUserIds: taggedUserIds,
    updatedAt: now,
  );

  Future<_Harness> pumpFlow(
    WidgetTester tester, {
    required CheckInDraft draft,
    Size size = const Size(390, 844),
    double textScale = 1,
    List<Place> places = const <Place>[],
    List<Flavor> flavors = const <Flavor>[],
    List<PublicProfile> friends = const <PublicProfile>[],
    _DraftRepository? drafts,
    _PublicationRepository? publication,
    _PublicationStateRepository? publicationState,
    _PlaceRepository? placeRepository,
    DeviceLocationService? locationService,
    PlaceMapSurfaceAdapter? mapAdapter,
    Stream<List<Place>>? placesStream,
    Stream<List<Flavor>>? flavorsStream,
    Stream<List<GelatoType>>? typesStream,
    AsyncValue<List<PublicProfile>>? friendsState,
    FlavorService? flavorService,
    SharedPreferences? preferences,
    CheckInLabelRepository? labels,
    VoidCallback? retryFriends,
    CheckInScreen screen = const CheckInScreen(),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final draftStore = drafts ?? _DraftRepository(draft);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(draftStore),
          checkInRepositoryProvider.overrideWithValue(
            publication ?? _PublicationRepository(),
          ),
          checkInPublicationRepositoryProvider.overrideWithValue(
            publicationState ?? _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(
            placeRepository ?? _PlaceRepository(),
          ),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          checkInIdGeneratorProvider.overrideWithValue(() => checkInId),
          checkInClockProvider.overrideWithValue(() => now),
          placesProvider.overrideWith(
            (ref) => placesStream ?? Stream.value(places),
          ),
          flavorsProvider.overrideWith(
            (ref) => flavorsStream ?? Stream.value(flavors),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => typesStream ?? Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            friendsState ?? AsyncData<List<PublicProfile>>(friends),
          ),
          timelineProjectionWaiterProvider.overrideWithValue((_, _) async {}),
          if (locationService != null)
            deviceLocationServiceProvider.overrideWithValue(locationService),
          if (mapAdapter != null)
            placeMapSurfaceAdapterProvider.overrideWithValue(mapAdapter),
          if (flavorService != null)
            flavorServiceProvider.overrideWithValue(flavorService),
          if (preferences != null)
            sharedPreferencesProvider.overrideWithValue(preferences),
          if (labels != null)
            checkInLabelRepositoryProvider.overrideWithValue(labels),
          if (labels == null && preferences != null)
            checkInLabelRepositoryProvider.overrideWithValue(
              PersistentCheckInLabelRepository(
                SharedPreferencesDraftPreferences(preferences),
              ),
            ),
          if (retryFriends != null)
            retryFriendshipSourcesProvider.overrideWithValue(retryFriends),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(draftStore);
  }

  testWidgets('compact and medium expose five equal top segments', (
    tester,
  ) async {
    for (final size in const <Size>[Size(390, 844), Size(768, 900)]) {
      await pumpFlow(tester, draft: draftAt(0), size: size);
      expect(
        find.byKey(const ValueKey<String>('check-in-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('check-in-wide-step-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('check-in-progress-segment')),
        findsNWidgets(5),
      );
      expect(
        find.byKey(const ValueKey<String>('check-in-sticky-navigation')),
        findsOneWidget,
      );
    }
  });

  testWidgets('wide uses a 220 rail and a form capped at 720', (tester) async {
    for (final width in const <double>[1024, 1440]) {
      await pumpFlow(tester, draft: draftAt(0), size: Size(width, 900));

      final rail = find.byKey(
        const ValueKey<String>('check-in-wide-step-rail'),
      );
      final form = find.byKey(const ValueKey<String>('check-in-form'));
      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).width, 220);
      expect(tester.getSize(form).width, lessThanOrEqualTo(720));
      expect(
        find.byKey(const ValueKey<String>('check-in-progress')),
        findsNothing,
      );
    }
  });

  testWidgets('only the persisted page body is mounted', (tester) async {
    for (var step = 0; step < 5; step++) {
      if (step > 0) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      await pumpFlow(tester, draft: draftAt(step));
      for (var candidate = 0; candidate < 5; candidate++) {
        expect(
          find.byKey(ValueKey<String>('check-in-page-$candidate')),
          candidate == step ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('new place uses GPS and map instead of raw coordinate fields', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(
        1,
        pendingPlace: PendingPlaceDraft(name: 'Nuova', address: 'Via Uno'),
      ),
    );

    expect(find.text('Latitudine'), findsNothing);
    expect(find.text('Longitudine'), findsNothing);
    expect(find.text('Usa la posizione'), findsOneWidget);
    expect(find.text('Scegli sulla mappa'), findsOneWidget);
  });

  testWidgets(
    'place GPS failure keeps input and map point resolves the draft',
    (tester) async {
      final places = _PlaceRepository();
      final map = _MapAdapter(const GeoPoint(46.12345, 10.54321));
      final harness = await pumpFlow(
        tester,
        draft: draftAt(
          1,
          pendingPlace: PendingPlaceDraft(name: 'Nuova', address: 'Via Uno'),
        ),
        placeRepository: places,
        locationService: DeviceLocationService(_DeniedLocationGateway()),
        mapAdapter: map,
      );

      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(find.textContaining('posizione valida'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nuova'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Via Uno'), findsOneWidget);

      await tester.tap(find.text('Scegli sulla mappa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('test-map-surface')));
      await tester.pumpAndSettle();
      expect(harness.drafts.value?.pendingPlace?.latitude, 46.12345);
      expect(harness.drafts.value?.pendingPlace?.longitude, 10.54321);

      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(places.creates.single.$3, const GeoPoint(46.12345, 10.54321));
      expect(
        find.byKey(const ValueKey<String>('check-in-page-2')),
        findsOneWidget,
      );
    },
  );

  testWidgets('gelato page requires type and one to four flavors', (
    tester,
  ) async {
    final flavors = <Flavor>[
      Flavor(id: 'pistacchio', name: 'Pistacchio'),
      Flavor(id: 'nocciola', name: 'Nocciola'),
      Flavor(id: 'limone', name: 'Limone'),
      Flavor(id: 'fragola', name: 'Fragola'),
      Flavor(id: 'crema', name: 'Crema'),
    ];
    final harness = await pumpFlow(tester, draft: draftAt(2), flavors: flavors);

    expect(find.byType(GelatoTypeSelector), findsOneWidget);
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(find.text('Seleziona il tipo di gelato.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cono'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(find.text('Seleziona da 1 a 4 gusti.'), findsOneWidget);

    for (final flavor in flavors.take(4)) {
      await tester.tap(
        find.byKey(ValueKey<String>('check-in-flavor-${flavor.id}')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(const ValueKey<String>('check-in-flavor-crema')),
    );
    await tester.pumpAndSettle();
    expect(harness.drafts.value?.flavorIds, hasLength(4));
    expect(find.text('Massimo 4 gusti.'), findsOneWidget);

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('check-in-page-3')),
      findsOneWidget,
    );
  });

  testWidgets('gelato catalog failure keeps bundled type choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final draftStore = _DraftRepository(draftAt(2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(draftStore),
          checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          placesProvider.overrideWith((ref) => Stream.value(const <Place>[])),
          flavorsProvider.overrideWith((ref) => Stream.value(const <Flavor>[])),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream<List<GelatoType>>.error(StateError('offline')),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
          ),
        ],
        child: const MaterialApp(home: CheckInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Cono'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Coppetta'), findsOneWidget);
  });

  testWidgets('flavor creation failure stays handled and retryable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlavorSelectionField(
            flavors: const <Flavor>[],
            selectedIds: const <String>[],
            onChanged: (_) {},
            onCreate: (_) async => throw StateError('offline'),
            onLimitReached: () {},
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nuovo gusto'),
      'Mandorla',
    );
    await tester.tap(find.byTooltip('Crea gusto'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('flow maps flavor creation failures to friendly copy', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(2),
      flavorService: _FlavorService(
        error: StateError('secret implementation details'),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nuovo gusto'),
      'Mandorla',
    );
    await tester.tap(find.byTooltip('Crea gusto'));
    await tester.pumpAndSettle();

    expect(find.text('Impossibile creare il gusto. Riprova.'), findsOneWidget);
    expect(find.textContaining('secret implementation'), findsNothing);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmapped Firebase flavor errors never expose backend details', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(2),
      flavorService: _FlavorService(
        error: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unexpected-backend-code',
          message: 'private backend collection path',
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nuovo gusto'),
      'Mandorla',
    );
    await tester.tap(find.byTooltip('Crea gusto'));
    await tester.pumpAndSettle();

    expect(find.text('Impossibile creare il gusto. Riprova.'), findsOneWidget);
    expect(find.textContaining('unexpected-backend-code'), findsNothing);
    expect(find.textContaining('private backend'), findsNothing);
  });

  testWidgets('created flavor does not clear a missing-type error', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(2),
      flavorService: _FlavorService(
        result: Flavor(id: 'mandorla-created', name: 'Mandorla'),
      ),
    );
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(find.text('Seleziona il tipo di gelato.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nuovo gusto'),
      'Mandorla',
    );
    await tester.tap(find.byTooltip('Crea gusto'));
    await tester.pumpAndSettle();

    expect(find.text('Seleziona il tipo di gelato.'), findsOneWidget);
  });

  testWidgets('created flavor keeps its human label through final review', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(2),
      places: <Place>[_place('place-1')],
      flavorService: _FlavorService(
        result: Flavor(id: 'mandorla-created', name: 'Mandorla tostata'),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cono'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nuovo gusto'),
      'Mandorla tostata',
    );
    await tester.tap(find.byTooltip('Crea gusto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stelle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mandorla tostata'), findsOneWidget);
    expect(find.textContaining('Gusto selezionato'), findsNothing);
    expect(find.textContaining('mandorla-created'), findsNothing);
  });

  testWidgets('inline-created place keeps its name through final review', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(
        1,
        pendingPlace: PendingPlaceDraft(
          name: 'Gelateria Nuvola',
          address: 'Via Fredda 7',
          latitude: 45,
          longitude: 9,
        ),
      ),
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
    );
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cono'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('check-in-flavor-pistacchio')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stelle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Gelateria Nuvola'), findsOneWidget);
    expect(find.text('Gelateria selezionata'), findsNothing);
  });

  testWidgets('restored review retains known labels when catalogs later lag', (
    tester,
  ) async {
    final places = StreamController<List<Place>>();
    final flavors = StreamController<List<Flavor>>();
    addTearDown(places.close);
    addTearDown(flavors.close);
    await pumpFlow(
      tester,
      draft: draftAt(4),
      placesStream: places.stream,
      flavorsStream: flavors.stream,
    );

    places.add(<Place>[_place('place-1', name: 'Gelateria Aurora')]);
    flavors.add(<Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio verde')]);
    await tester.pumpAndSettle();
    expect(find.text('Gelateria Aurora'), findsOneWidget);
    expect(find.textContaining('Pistacchio verde'), findsOneWidget);

    places.add(const <Place>[]);
    flavors.add(const <Flavor>[]);
    await tester.pumpAndSettle();
    expect(find.text('Gelateria Aurora'), findsOneWidget);
    expect(find.textContaining('Pistacchio verde'), findsOneWidget);
    expect(find.text('Gelateria selezionata'), findsNothing);
    expect(find.textContaining('Gusto selezionato'), findsNothing);
  });

  testWidgets('label cache survives screen recreation with empty catalogs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await pumpFlow(
      tester,
      draft: draftAt(4),
      places: <Place>[_place('place-1', name: 'Gelateria Persistita')],
      flavors: <Flavor>[
        Flavor(id: 'pistacchio', name: 'Pistacchio Persistito'),
      ],
      preferences: preferences,
    );
    expect(find.text('Gelateria Persistita'), findsOneWidget);
    expect(find.textContaining('Pistacchio Persistito'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpFlow(tester, draft: draftAt(4), preferences: preferences);
    expect(find.text('Gelateria Persistita'), findsOneWidget);
    expect(find.textContaining('Pistacchio Persistito'), findsOneWidget);
    expect(find.text('Gelateria selezionata'), findsNothing);
    expect(find.textContaining('Gusto selezionato'), findsNothing);
  });

  testWidgets('restored Place step keeps the cached selected place', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final restored = draftAt(2).copyWith(currentStep: 1);
    await pumpFlow(
      tester,
      draft: restored,
      places: <Place>[_place('place-1', name: 'Gelateria del Passo')],
      preferences: preferences,
    );
    expect(find.textContaining('Gelateria del Passo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpFlow(tester, draft: restored, preferences: preferences);

    expect(find.textContaining('Gelateria del Passo'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, 'place-1');
  });

  testWidgets('restored Gelato step keeps cached remote type and flavors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final restored = draftAt(3).copyWith(
      currentStep: 2,
      gelatoTypeId: 'tipo-remoto',
      flavorIds: const <String>['gusto-remoto'],
    );
    const remoteType = GelatoType(
      id: 'tipo-remoto',
      name: 'Coppa remota',
      sortOrder: 99,
    );
    await pumpFlow(
      tester,
      draft: restored,
      typesStream: Stream.value(const <GelatoType>[remoteType]),
      flavors: <Flavor>[Flavor(id: 'gusto-remoto', name: 'Mandorla remota')],
      preferences: preferences,
    );
    expect(find.widgetWithText(ChoiceChip, 'Coppa remota'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Mandorla remota'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpFlow(
      tester,
      draft: restored,
      typesStream: Stream<List<GelatoType>>.error(StateError('offline')),
      flavorsStream: Stream<List<Flavor>>.error(StateError('offline')),
      preferences: preferences,
    );

    expect(find.widgetWithText(ChoiceChip, 'Coppa remota'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Mandorla remota'), findsOneWidget);
    expect(find.text('Gusto salvato'), findsNothing);
  });

  testWidgets(
    'label load failure blocks live-catalog publish until recovery is stable',
    (tester) async {
      final publication = _PublicationRepository();
      final labels = _LabelRepository()
        ..loadError = const FormatException('corrupt labels');
      await pumpFlow(
        tester,
        draft: draftAt(4),
        places: <Place>[_place('place-1', name: 'Gelateria Live')],
        flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio Live')],
        publication: publication,
        labels: labels,
      );

      expect(
        find.text('Impossibile ripristinare le etichette del check-in.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Riprova etichette'),
        findsOneWidget,
      );
      expect(find.text('Ricostruisci cache'), findsOneWidget);
      expect(find.text('Gelateria selezionata'), findsNothing);
      expect(find.textContaining('Gusto selezionato'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Pubblica'), findsNothing);
      expect(publication.calls, 0);

      expect(find.text('Gelateria Live'), findsOneWidget);
      expect(find.textContaining('Pistacchio Live'), findsOneWidget);
      expect(publication.calls, 0);

      labels
        ..loadError = null
        ..pendingSave = Completer<void>();
      final bottomRetry = find.widgetWithText(
        FilledButton,
        'Riprova etichette',
      );
      expect(tester.widget<FilledButton>(bottomRetry).onPressed, isNotNull);
      await tester.tap(bottomRetry);
      while (labels.saveCalls == 0) {
        await tester.pump();
      }
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'Pubblica'), findsNothing);
      expect(find.text('Salvataggio etichette'), findsOneWidget);
      expect(publication.calls, 0);

      labels.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Pubblica'), findsOneWidget);
      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();
      expect(publication.calls, 1);
    },
  );

  testWidgets('experience requires rating and caps the optional note at 500', (
    tester,
  ) async {
    await pumpFlow(tester, draft: draftAt(3));
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(find.text('Seleziona un voto da 1 a 5.'), findsOneWidget);

    final note = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Nota (opzionale)'),
    );
    expect(note.maxLength, 500);
    await tester.tap(find.byTooltip('5 stelle'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey<String>('check-in-rating-5')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('note edits do not clear a missing-rating validation error', (
    tester,
  ) async {
    await pumpFlow(tester, draft: draftAt(3));
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(find.text('Seleziona un voto da 1 a 5.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nota (opzionale)'),
      'Nota senza voto',
    );
    await tester.pumpAndSettle();
    expect(find.text('Seleziona un voto da 1 a 5.'), findsOneWidget);
  });

  testWidgets('partial new-place edits keep the combined required error', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      draft: draftAt(
        1,
        pendingPlace: PendingPlaceDraft(name: '', address: ''),
      ),
    );
    await tester.tap(find.text('Continua'));
    await tester.pump();
    expect(
      find.text('Inserisci nome e indirizzo della gelateria.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('check-in-place-name')),
      'Solo nome',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Inserisci nome e indirizzo della gelateria.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'share review uses human labels and one accepted-friends publish',
    (tester) async {
      final alice = _profile('friend-alice', 'Alice Bianchi');
      await pumpFlow(
        tester,
        draft: draftAt(4, taggedUserIds: const <String>['friend-alice']),
        places: <Place>[_place('place-1')],
        flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
        friends: <PublicProfile>[alice],
      );

      expect(find.text('Gelateria Aurora'), findsOneWidget);
      expect(find.textContaining('Cono'), findsOneWidget);
      expect(find.textContaining('Pistacchio'), findsOneWidget);
      expect(find.text('Alice Bianchi'), findsWidgets);
      expect(find.textContaining('place-1'), findsNothing);
      expect(find.textContaining('friend-alice'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Pubblica'), findsOneWidget);
    },
  );

  testWidgets('Back persists every value and restored draft opens its page', (
    tester,
  ) async {
    final harness = await pumpFlow(
      tester,
      draft: draftAt(4, taggedUserIds: const <String>['friend-alice']),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      friends: <PublicProfile>[_profile('friend-alice', 'Alice Bianchi')],
    );
    await tester.tap(find.text('Indietro'));
    await tester.pumpAndSettle();

    expect(harness.drafts.value?.currentStep, 3);
    expect(harness.drafts.value?.placeId, 'place-1');
    expect(harness.drafts.value?.gelatoTypeId, 'cono');
    expect(harness.drafts.value?.flavorIds, const <String>['pistacchio']);
    expect(harness.drafts.value?.taggedUserIds, const <String>['friend-alice']);
    expect(
      find.byKey(const ValueKey<String>('check-in-page-3')),
      findsOneWidget,
    );
  });

  testWidgets(
    'publication failure preserves review and retries the same action',
    (tester) async {
      final publication = _PublicationRepository()
        ..error = const CheckInRetryableFailure();
      final harness = await pumpFlow(
        tester,
        draft: draftAt(4),
        places: <Place>[_place('place-1')],
        flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
        publication: publication,
      );
      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Riprova'), findsOneWidget);
      expect(harness.drafts.value?.reviewText, 'Cremoso e bilanciato');
      publication.error = null;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(publication.calls, 2);
    },
  );

  testWidgets('failed dirty draft save retries before one publication', (
    tester,
  ) async {
    final drafts = _DraftRepository(draftAt(4));
    final publication = _PublicationRepository();
    await pumpFlow(
      tester,
      draft: draftAt(4),
      drafts: drafts,
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      friends: <PublicProfile>[_profile('friend-alice', 'Alice Bianchi')],
      publication: publication,
    );

    drafts.failNextSave = true;
    await tester.tap(find.text('Alice Bianchi'));
    await tester.pumpAndSettle();

    expect(drafts.saveCalls, 1);
    expect(find.widgetWithText(FilledButton, 'Riprova'), findsOneWidget);
    expect(publication.calls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Riprova'));
    await tester.pumpAndSettle();

    expect(drafts.saveCalls, 2);
    expect(drafts.value?.taggedUserIds, const <String>['friend-alice']);
    expect(find.widgetWithText(FilledButton, 'Pubblica'), findsOneWidget);
    expect(publication.calls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Pubblica'));
    await tester.pumpAndSettle();

    expect(publication.calls, 1);
    expect(drafts.saveCalls, 2);
  });

  testWidgets('successful cleanup waits for projection then routes once', (
    tester,
  ) async {
    final publication = _PublicationRepository();
    final drafts = _DraftRepository(draftAt(4));
    final projectionReady = Completer<void>();
    final router = GoRouter(
      initialLocation: '/check-in',
      routes: <RouteBase>[
        GoRoute(path: '/check-in', builder: (_, _) => const CheckInScreen()),
        GoRoute(
          path: '/timeline',
          builder: (_, _) => const Scaffold(body: Text('Timeline target')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInRepositoryProvider.overrideWithValue(publication),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[_place('place-1')]),
          ),
          flavorsProvider.overrideWith(
            (ref) => Stream.value(<Flavor>[
              Flavor(id: 'pistacchio', name: 'Pistacchio'),
            ]),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
          ),
          timelineProjectionWaiterProvider.overrideWithValue(
            (_, _) => projectionReady.future,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pubblica'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/check-in');
    expect(find.text('Check-in pubblicato'), findsOneWidget);

    projectionReady.complete();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/timeline');
    expect(find.text('Timeline target'), findsOneWidget);
    expect(publication.calls, 1);
    expect(drafts.value, isNull);
  });

  testWidgets('duplicate publish activation completes exactly once', (
    tester,
  ) async {
    final publication = _PublicationRepository();
    final drafts = _DraftRepository(draftAt(4));
    final router = GoRouter(
      initialLocation: '/check-in',
      routes: <RouteBase>[
        GoRoute(path: '/check-in', builder: (_, _) => const CheckInScreen()),
        GoRoute(
          path: '/timeline',
          builder: (_, _) => const Scaffold(body: Text('Timeline target')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInRepositoryProvider.overrideWithValue(publication),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[_place('place-1')]),
          ),
          flavorsProvider.overrideWith(
            (ref) => Stream.value(<Flavor>[
              Flavor(id: 'pistacchio', name: 'Pistacchio'),
            ]),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
          ),
          timelineProjectionWaiterProvider.overrideWithValue((_, _) async {}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final publish = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pubblica'))
        .onPressed;
    expect(publish, isNotNull);
    publish!();
    publish();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.routeInformationProvider.value.uri.path, '/timeline');
    expect(find.text('Timeline target'), findsOneWidget);
    expect(publication.calls, 1);
    expect(drafts.value, isNull);
  });

  testWidgets(
    'delayed valid place preselection is applied once catalog loads',
    (tester) async {
      final catalog = StreamController<List<Place>>();
      addTearDown(catalog.close);
      final harness = await pumpFlow(
        tester,
        draft: draftAt(1),
        placesStream: catalog.stream,
        screen: const CheckInScreen(placeId: 'place-delayed'),
      );
      expect(harness.drafts.value?.placeId, isNull);
      catalog.add(<Place>[_place('place-delayed')]);
      await tester.pumpAndSettle();
      expect(harness.drafts.value?.placeId, 'place-delayed');
    },
  );

  testWidgets('delayed accepted friend preselection applies after load', (
    tester,
  ) async {
    final accepted = Completer<List<PublicProfile>>();
    final drafts = _DraftRepository(draftAt(4));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[_place('place-1')]),
          ),
          flavorsProvider.overrideWith(
            (ref) => Stream.value(<Flavor>[
              Flavor(id: 'pistacchio', name: 'Pistacchio'),
            ]),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesForUidProvider.overrideWith(
            (ref, uid) => accepted.future,
          ),
        ],
        child: const MaterialApp(
          home: CheckInScreen(prefillFriendId: 'friend-alice'),
        ),
      ),
    );
    await tester.pump();
    accepted.complete(<PublicProfile>[
      _profile('friend-alice', 'Alice Bianchi'),
    ]);
    await tester.pumpAndSettle();
    expect(drafts.value?.taggedUserIds, const <String>['friend-alice']);
  });

  testWidgets('unaccepted friend query preselection is ignored', (
    tester,
  ) async {
    final harness = await pumpFlow(
      tester,
      draft: draftAt(4),
      friends: <PublicProfile>[_profile('friend-alice', 'Alice Bianchi')],
      screen: const CheckInScreen(prefillFriendId: 'revoked-friend'),
    );
    expect(harness.drafts.value?.taggedUserIds, isEmpty);
    expect(find.textContaining('revoked-friend'), findsNothing);
  });

  testWidgets(
    'successful accepted load removes revoked restored tags before publish',
    (tester) async {
      final publication = _PublicationRepository();
      final harness = await pumpFlow(
        tester,
        draft: draftAt(
          4,
          taggedUserIds: const <String>['friend-alice', 'revoked-friend'],
        ),
        places: <Place>[_place('place-1')],
        flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
        friends: <PublicProfile>[_profile('friend-alice', 'Alice Bianchi')],
        publication: publication,
      );

      expect(harness.drafts.value?.taggedUserIds, const <String>[
        'friend-alice',
      ]);
      expect(find.textContaining('revoked-friend'), findsNothing);
      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();
      expect(publication.lastDraft?.taggedUserIds, const <String>[
        'friend-alice',
      ]);
    },
  );

  testWidgets('publish waits until restored tags can be verified', (
    tester,
  ) async {
    final publication = _PublicationRepository();
    final labels = _LabelRepository()
      ..loadedLabels = const CheckInDisplayLabels(
        friendNames: <String, String>{'friend-alice': 'Alice Bianchi'},
      );
    await pumpFlow(
      tester,
      draft: draftAt(4, taggedUserIds: const <String>['friend-alice']),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      friendsState: AsyncError<List<PublicProfile>>(
        StateError('offline'),
        StackTrace.empty,
      ),
      labels: labels,
      publication: publication,
    );

    await tester.tap(find.text('Pubblica'));
    await tester.pump();

    expect(publication.calls, 0);
    expect(
      find.text('Attendi la verifica degli amici taggati e riprova.'),
      findsOneWidget,
    );
  });

  testWidgets('friends error retries the source or clears tags safely', (
    tester,
  ) async {
    var retryCalls = 0;
    final publication = _PublicationRepository();
    final labels = _LabelRepository()
      ..loadedLabels = const CheckInDisplayLabels(
        friendNames: <String, String>{'friend-alice': 'Alice Bianchi'},
      );
    final harness = await pumpFlow(
      tester,
      draft: draftAt(4, taggedUserIds: const <String>['friend-alice']),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      friendsState: AsyncError<List<PublicProfile>>(
        StateError('offline'),
        StackTrace.empty,
      ),
      retryFriends: () => retryCalls++,
      labels: labels,
      publication: publication,
    );

    expect(find.text('Ricarica amici'), findsOneWidget);
    expect(find.text('Rimuovi tag'), findsOneWidget);
    await tester.tap(find.text('Ricarica amici'));
    await tester.pump();
    expect(retryCalls, 1);

    await tester.tap(find.text('Pubblica'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Riprova amici'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Riprova amici'));
    await tester.pump();
    expect(retryCalls, 2);
    expect(publication.calls, 0);

    await tester.tap(find.text('Rimuovi tag'));
    await tester.pumpAndSettle();
    expect(harness.drafts.value?.taggedUserIds, isEmpty);
    await tester.tap(find.text('Pubblica'));
    await tester.pumpAndSettle();
    expect(publication.calls, 1);
  });

  testWidgets('successful publication clears the draft label cache', (
    tester,
  ) async {
    final labels = _LabelRepository();
    await pumpFlow(
      tester,
      draft: draftAt(4),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      labels: labels,
    );

    await tester.tap(find.text('Pubblica'));
    await tester.pumpAndSettle();

    expect(labels.cleared, <(String, String)>[('alice', checkInId)]);
  });

  testWidgets('pending label persistence guards every exit', (tester) async {
    final labels = _LabelRepository()..pendingSave = Completer<void>();
    await pumpFlow(
      tester,
      draft: draftAt(4),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      labels: labels,
    );
    while (labels.saveCalls == 0) {
      await tester.pump();
    }

    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Chiudi check-in'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Indietro'))
          .onPressed,
      isNull,
    );

    labels.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );
  });

  testWidgets('label persistence changes the primary CTA only on review', (
    tester,
  ) async {
    for (var step = 0; step < 4; step++) {
      if (step > 0) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
      final labels = _LabelRepository()..pendingSave = Completer<void>();
      final draft = switch (step) {
        0 => draftAt(0),
        1 => draftAt(2).copyWith(currentStep: 1),
        2 => draftAt(3).copyWith(currentStep: 2),
        _ => draftAt(3),
      };
      await pumpFlow(
        tester,
        draft: draft,
        places: <Place>[_place('place-1')],
        flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
        labels: labels,
      );
      if (step > 0) {
        while (labels.saveCalls == 0) {
          await tester.pump();
        }
      }

      final continueButton = find.widgetWithText(FilledButton, 'Continua');
      expect(continueButton, findsOneWidget, reason: 'step $step');
      expect(
        tester.widget<FilledButton>(continueButton).onPressed,
        isNotNull,
        reason: 'step $step',
      );
      expect(find.text('Salvataggio etichette'), findsNothing);

      labels.pendingSave!.complete();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('failed label persistence remains guarded and retryable', (
    tester,
  ) async {
    final labels = _LabelRepository()..saveError = StateError('disk');
    await pumpFlow(
      tester,
      draft: draftAt(4),
      places: <Place>[_place('place-1')],
      flavors: <Flavor>[Flavor(id: 'pistacchio', name: 'Pistacchio')],
      labels: labels,
    );
    while (labels.saveCalls == 0) {
      await tester.pump();
    }
    await tester.pump();

    expect(find.text('Riprova salvataggio'), findsOneWidget);
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );

    labels.saveError = null;
    await tester.tap(find.text('Riprova salvataggio'));
    await tester.pumpAndSettle();
    expect(labels.saveCalls, 2);
    expect(
      find.text('Impossibile salvare le etichette del check-in. Riprova.'),
      findsNothing,
    );
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );
  });

  testWidgets(
    'same-UID new draft resets friend map and local error transients',
    (tester) async {
      const newDraftId = 'ZYXWVUTSRQPONMLKJIHG';
      final oldDraft = draftAt(
        1,
        pendingPlace: PendingPlaceDraft(name: 'Vecchia', address: 'Via Uno'),
      );
      final drafts = _DraftRepository(oldDraft);
      final labels = _LabelRepository()
        ..loadedLabels = const CheckInDisplayLabels(
          friendNames: <String, String>{'friend-alice': 'Alice Bianchi'},
        );
      final places = _PlaceRepository();
      final map = _MapAdapter(const GeoPoint(46.12345, 10.54321));
      var retryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInLabelRepositoryProvider.overrideWithValue(labels),
          checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(places),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          deviceLocationServiceProvider.overrideWithValue(
            DeviceLocationService(_DeniedLocationGateway()),
          ),
          placeMapSurfaceAdapterProvider.overrideWithValue(map),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[_place('place-1')]),
          ),
          flavorsProvider.overrideWith(
            (ref) => Stream.value(<Flavor>[
              Flavor(id: 'pistacchio', name: 'Pistacchio'),
            ]),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            AsyncError<List<PublicProfile>>(
              StateError('offline'),
              StackTrace.empty,
            ),
          ),
          retryFriendshipSourcesProvider.overrideWithValue(() => retryCalls++),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CheckInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final originalElement = tester.element(find.byType(CheckInFlow));

      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(find.textContaining('posizione valida'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('test-map-surface')),
        findsOneWidget,
      );

      drafts.value = draftAt(4, taggedUserIds: const <String>['friend-alice']);
      container.invalidate(checkInFlowProvider('alice'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.element(find.byType(CheckInFlow)), originalElement),
        isTrue,
      );
      await tester.tap(find.text('Pubblica'));
      await tester.pump();
      expect(
        find.text('Attendi la verifica degli amici taggati e riprova.'),
        findsOneWidget,
      );

      drafts.value = CheckInDraft(
        id: newDraftId,
        currentStep: 1,
        localPhotoName: 'gelato.jpg',
        stagingObjectPath: 'staging/alice/$newDraftId.jpg',
        placeId: null,
        pendingPlace: PendingPlaceDraft(name: 'Nuova', address: 'Via Due'),
        gelatoTypeId: null,
        flavorIds: const <String>[],
        rating: null,
        reviewText: '',
        taggedUserIds: const <String>[],
        updatedAt: now,
      );
      container.invalidate(checkInFlowProvider('alice'));
      await tester.pumpAndSettle();

      expect(
        identical(tester.element(find.byType(CheckInFlow)), originalElement),
        isTrue,
      );
      expect(find.textContaining('posizione valida'), findsNothing);
      expect(
        find.text('Attendi la verifica degli amici taggati e riprova.'),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('test-map-surface')),
        findsNothing,
      );

      await tester.tap(find.text('Scegli sulla mappa'));
      await tester.pumpAndSettle();
      final mapSurface = find.byKey(const ValueKey<String>('test-map-surface'));
      tester.widget<GestureDetector>(mapSurface).onTap!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('check-in-page-2')),
        findsOneWidget,
      );
      expect(places.creates.single.$1, 'Nuova');
      expect(retryCalls, 0);
    },
  );

  testWidgets(
    'stale pending flavor completion before rebuild cannot mutate a same-UID draft',
    (tester) async {
      const newDraftId = 'QWERTYUIOPASDFGHJKLZ';
      final drafts = _DraftRepository(draftAt(2));
      final labels = _LabelRepository();
      final pendingFlavor = Completer<Flavor>();
      addTearDown(() async {
        if (!pendingFlavor.isCompleted) {
          pendingFlavor.complete(
            Flavor(id: 'tear-down-flavor', name: 'Tear down'),
          );
          await Future<void>.microtask(() {});
        }
      });
      final flavorService = _FlavorService(pending: pendingFlavor);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInLabelRepositoryProvider.overrideWithValue(labels),
          checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          flavorServiceProvider.overrideWithValue(flavorService),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[
              _place('place-1'),
              _place('place-new', name: 'Gelateria Nuova'),
            ]),
          ),
          flavorsProvider.overrideWith((ref) => Stream.value(const <Flavor>[])),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CheckInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final originalElement = tester.element(find.byType(CheckInFlow));
      labels.saves.clear();

      final searchFlavorField = find.widgetWithText(
        TextField,
        'Cerca un gusto',
      );
      await tester.ensureVisible(searchFlavorField);
      await tester.enterText(searchFlavorField, 'Pistacchio');
      final newFlavorField = find.widgetWithText(TextField, 'Nuovo gusto');
      await tester.ensureVisible(newFlavorField);
      await tester.enterText(newFlavorField, 'Backend Segreto');
      await tester.tap(find.byTooltip('Crea gusto'));
      while (flavorService.calls == 0) {
        await tester.pump();
      }

      drafts.value = CheckInDraft(
        id: newDraftId,
        currentStep: 2,
        localPhotoName: 'gelato.jpg',
        stagingObjectPath: 'staging/alice/$newDraftId.jpg',
        placeId: 'place-new',
        pendingPlace: null,
        gelatoTypeId: null,
        flavorIds: const <String>[],
        rating: null,
        reviewText: '',
        taggedUserIds: const <String>[],
        updatedAt: now,
      );
      container.invalidate(checkInFlowProvider('alice'));
      final keepAlive = container.listen(
        checkInFlowProvider('alice'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);
      for (var attempt = 0; attempt < 100; attempt++) {
        if (container.read(checkInFlowProvider('alice')).draft?.id ==
            newDraftId) {
          break;
        }
        await Future<void>.microtask(() {});
      }
      expect(
        container.read(checkInFlowProvider('alice')).draft?.id,
        newDraftId,
      );

      pendingFlavor.complete(Flavor(id: 'old-flavor', name: 'Backend Segreto'));
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});

      expect(drafts.value?.id, newDraftId);
      expect(drafts.value?.flavorIds, isEmpty);

      await tester.pumpAndSettle();

      expect(
        identical(tester.element(find.byType(CheckInFlow)), originalElement),
        isTrue,
      );
      expect(tester.widget<TextField>(searchFlavorField).controller?.text, '');
      expect(tester.widget<TextField>(newFlavorField).controller?.text, '');
      expect(find.widgetWithText(InputChip, 'Backend Segreto'), findsNothing);
      for (final save in labels.saves.where(
        (save) => save.draftId == newDraftId,
      )) {
        expect(save.labels.flavorNames, isNot(contains('old-flavor')));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale pending picker completion before rebuild cannot upload to a same-UID draft',
    (tester) async {
      const newDraftId = 'ZXCVBNMASDFGHJKLQWER';
      final pendingImage = Completer<XFile?>();
      addTearDown(() async {
        if (!pendingImage.isCompleted) {
          pendingImage.complete(null);
          await Future<void>.microtask(() {});
        }
      });
      final picker = _PendingImagePicker(pendingImage);
      final previousPicker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = previousPicker);
      final drafts = _DraftRepository(
        draftAt(0).copyWith(localPhotoName: null, stagingObjectPath: null),
      );
      final storage = _StorageGateway();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInLabelRepositoryProvider.overrideWithValue(_LabelRepository()),
          checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(storage),
          ),
          placesProvider.overrideWith((ref) => Stream.value(const <Place>[])),
          flavorsProvider.overrideWith((ref) => Stream.value(const <Flavor>[])),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CheckInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Galleria'));
      expect(picker.calls, 1);

      drafts.value = CheckInDraft(
        id: newDraftId,
        currentStep: 0,
        localPhotoName: null,
        stagingObjectPath: null,
        placeId: null,
        pendingPlace: null,
        gelatoTypeId: null,
        flavorIds: const <String>[],
        rating: null,
        reviewText: '',
        taggedUserIds: const <String>[],
        updatedAt: now,
      );
      container.invalidate(checkInFlowProvider('alice'));
      final keepAlive = container.listen(
        checkInFlowProvider('alice'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);
      for (var attempt = 0; attempt < 100; attempt++) {
        if (container.read(checkInFlowProvider('alice')).draft?.id ==
            newDraftId) {
          break;
        }
        await Future<void>.microtask(() {});
      }
      expect(
        container.read(checkInFlowProvider('alice')).draft?.id,
        newDraftId,
      );

      pendingImage.complete(
        XFile.fromData(
          _onePixelPng(),
          name: 'old-draft.png',
          mimeType: 'image/png',
        ),
      );
      for (var attempt = 0; attempt < 20; attempt++) {
        await Future<void>.microtask(() {});
      }

      expect(storage.putPaths, isEmpty);
      expect(drafts.value?.id, newDraftId);
      expect(drafts.value?.localPhotoName, isNull);
      expect(drafts.value?.stagingObjectPath, isNull);
    },
  );

  testWidgets(
    'stale publish continuation before rebuild cannot publish a same-UID draft',
    (tester) async {
      const newDraftId = 'MNBVCXZLKJHGFDSAPOIU';
      var accepted = <PublicProfile>[_profile('friend-alice', 'Alice Bianchi')];
      final drafts = _DraftRepository(
        draftAt(4, taggedUserIds: const <String>['friend-alice']),
      );
      final publication = _PublicationRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
          checkInDraftRepositoryProvider.overrideWithValue(drafts),
          checkInLabelRepositoryProvider.overrideWithValue(_LabelRepository()),
          checkInRepositoryProvider.overrideWithValue(publication),
          checkInPublicationRepositoryProvider.overrideWithValue(
            _PublicationStateRepository(),
          ),
          placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_StorageGateway()),
          ),
          placesProvider.overrideWith(
            (ref) => Stream.value(<Place>[_place('place-1')]),
          ),
          flavorsProvider.overrideWith(
            (ref) => Stream.value(<Flavor>[
              Flavor(id: 'pistacchio', name: 'Pistacchio'),
            ]),
          ),
          gelatoTypesProvider.overrideWith(
            (ref) => Stream.value(defaultGelatoTypes),
          ),
          acceptedFriendProfilesProvider.overrideWith(
            (ref) => AsyncData<List<PublicProfile>>(accepted),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CheckInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      accepted = <PublicProfile>[];
      container.invalidate(acceptedFriendProfilesProvider);
      expect(container.read(acceptedFriendProfilesProvider).value, isEmpty);
      final pendingReconciliation = Completer<void>();
      addTearDown(() {
        if (!pendingReconciliation.isCompleted) {
          pendingReconciliation.complete();
        }
      });
      drafts.pendingSave = pendingReconciliation;
      final baselineSaves = drafts.saveCalls;

      await tester.tap(find.text('Pubblica'));
      expect(drafts.saveCalls, baselineSaves + 1);

      drafts.value = CheckInDraft(
        id: newDraftId,
        currentStep: 4,
        localPhotoName: 'new.jpg',
        stagingObjectPath: 'staging/alice/$newDraftId.jpg',
        placeId: 'place-new',
        pendingPlace: null,
        gelatoTypeId: 'cono',
        flavorIds: const <String>['pistacchio'],
        rating: 4,
        reviewText: 'Nuova bozza',
        taggedUserIds: const <String>[],
        updatedAt: now,
      );
      container.invalidate(checkInFlowProvider('alice'));
      final keepAlive = container.listen(
        checkInFlowProvider('alice'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);
      for (var attempt = 0; attempt < 100; attempt++) {
        if (container.read(checkInFlowProvider('alice')).draft?.id ==
            newDraftId) {
          break;
        }
        await Future<void>.microtask(() {});
      }
      expect(
        container.read(checkInFlowProvider('alice')).draft?.id,
        newDraftId,
      );

      pendingReconciliation.complete();
      for (var attempt = 0; attempt < 20; attempt++) {
        await Future<void>.microtask(() {});
      }

      expect(publication.calls, 0);
      expect(drafts.value?.id, newDraftId);
    },
  );

  testWidgets('UID switch isolates same-id drafts and deferred label saves', (
    tester,
  ) async {
    final aliceDraft = draftAt(4).copyWith(
      placeId: 'place-alice',
      flavorIds: const <String>['flavor-alice'],
    );
    final bobDraft = draftAt(
      4,
    ).copyWith(placeId: 'place-bob', flavorIds: const <String>['flavor-bob']);
    final drafts = _UidDraftRepository(<String, CheckInDraft>{
      'alice': aliceDraft,
      'bob': bobDraft,
    });
    final labels = _UidLabelRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => _FakeUser(ref.watch(_testUidProvider)),
        ),
        checkInDraftRepositoryProvider.overrideWithValue(drafts),
        checkInLabelRepositoryProvider.overrideWithValue(labels),
        checkInRepositoryProvider.overrideWithValue(_PublicationRepository()),
        checkInPublicationRepositoryProvider.overrideWithValue(
          _PublicationStateRepository(),
        ),
        placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
        storageServiceProvider.overrideWithValue(
          StorageService.forTesting(_StorageGateway()),
        ),
        placesProvider.overrideWith(
          (ref) => Stream.value(<Place>[
            _place('place-alice', name: 'Gelateria Alice'),
            _place('place-bob', name: 'Gelateria Bob'),
          ]),
        ),
        flavorsProvider.overrideWith(
          (ref) => Stream.value(<Flavor>[
            Flavor(id: 'flavor-alice', name: 'Gusto Alice'),
            Flavor(id: 'flavor-bob', name: 'Gusto Bob'),
          ]),
        ),
        gelatoTypesProvider.overrideWith(
          (ref) => Stream.value(defaultGelatoTypes),
        ),
        acceptedFriendProfilesProvider.overrideWithValue(
          const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckInScreen()),
      ),
    );
    while (!labels.saves.any((save) => save.uid == 'alice')) {
      await tester.pump();
    }

    container.read(_testUidProvider.notifier).setUid('bob');
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('check-in-flow-bob')),
      findsOneWidget,
    );
    expect(find.text('Gelateria Bob'), findsOneWidget);
    expect(find.text('Gelateria Alice'), findsNothing);

    labels.aliceSave.complete();
    await tester.pumpAndSettle();
    expect(find.text('Gelateria Bob'), findsOneWidget);
    for (final save in labels.saves.where((save) => save.uid == 'bob')) {
      expect(save.labels.placeNames.keys, isNot(contains('place-alice')));
      expect(save.labels.flavorNames.keys, isNot(contains('flavor-alice')));
    }
    expect(drafts.savedUids, isEmpty);
  });

  testWidgets('clean metadata can pop while a pending save remains guarded', (
    tester,
  ) async {
    final drafts = _DraftRepository(draftAt(3));
    await pumpFlow(tester, draft: draftAt(3), drafts: drafts);
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );

    drafts.pendingSave = Completer<void>();
    await tester.tap(find.byTooltip('5 stelle'));
    await tester.pump();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );
    drafts.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );
  });

  testWidgets('keyboard activation and semantics expose reachable controls', (
    tester,
  ) async {
    await pumpFlow(tester, draft: draftAt(0));
    final continueButton = find.widgetWithText(FilledButton, 'Continua');
    expect(tester.getSize(continueButton).height, greaterThanOrEqualTo(44));
    final buttonElement = tester.element(continueButton);
    var focusedPrimary = false;
    for (var index = 0; index < 12 && !focusedPrimary; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (identical(focusedContext, buttonElement)) {
        focusedPrimary = true;
      } else {
        focusedContext?.visitAncestorElements((element) {
          if (identical(element, buttonElement)) {
            focusedPrimary = true;
            return false;
          }
          return true;
        });
      }
    }
    expect(focusedPrimary, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.text('Aggiungi e carica una foto prima di continuare.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const <Size>[
    Size(390, 844),
    Size(768, 900),
    Size(1024, 900),
    Size(1440, 1000),
  ]) {
    testWidgets(
      'real appRouter keeps /check-in outside shell at ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            routerAuthSessionProvider.overrideWithValue(_RouterSession()),
            currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
            checkInDraftRepositoryProvider.overrideWithValue(
              _DraftRepository(draftAt(0)),
            ),
            checkInRepositoryProvider.overrideWithValue(
              _PublicationRepository(),
            ),
            checkInPublicationRepositoryProvider.overrideWithValue(
              _PublicationStateRepository(),
            ),
            placeRepositoryProvider.overrideWithValue(_PlaceRepository()),
            storageServiceProvider.overrideWithValue(
              StorageService.forTesting(_StorageGateway()),
            ),
            placesProvider.overrideWith((ref) => Stream.value(const <Place>[])),
            flavorsProvider.overrideWith(
              (ref) => Stream.value(const <Flavor>[]),
            ),
            gelatoTypesProvider.overrideWith(
              (ref) => Stream.value(defaultGelatoTypes),
            ),
            acceptedFriendProfilesProvider.overrideWithValue(
              const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = container.read(appRouterProvider)..go('/check-in');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, '/check-in');
        final checkInRoute = ModalRoute.of(
          tester.element(find.byKey(const ValueKey<String>('check-in-form'))),
        );
        expect(checkInRoute?.opaque, isFalse);
        expect(find.byType(AuthenticatedShell), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('check-in-fab')),
          findsNothing,
        );
        if (size.width == 390) {
          await tester.tap(find.widgetWithText(TextButton, 'Chiudi'));
          await tester.pump();
          expect(router.routeInformationProvider.value.uri.path, '/timeline');
          router.go('/check-in');
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'two hundred percent text and short height keep navigation reachable',
    (tester) async {
      await pumpFlow(
        tester,
        draft: draftAt(3),
        size: const Size(390, 560),
        textScale: 2,
      );

      expect(find.text('Continua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Harness {
  const _Harness(this.drafts);

  final _DraftRepository drafts;
}

final class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestUidController extends Notifier<String> {
  @override
  String build() => 'alice';

  void setUid(String uid) => state = uid;
}

final class _UidDraftRepository implements CheckInDraftRepository {
  _UidDraftRepository(this.values);

  final Map<String, CheckInDraft> values;
  final List<String> savedUids = <String>[];

  @override
  Future<void> clear(String uid) async => values.remove(uid);

  @override
  Future<CheckInDraft?> load(String uid) async => values[uid];

  @override
  Future<void> save(String uid, CheckInDraft draft) async {
    savedUids.add(uid);
    values[uid] = draft;
  }
}

typedef _LabelSave = ({
  String uid,
  String draftId,
  CheckInDisplayLabels labels,
});

final class _UidLabelRepository implements CheckInLabelRepository {
  final aliceSave = Completer<void>();
  final List<_LabelSave> saves = <_LabelSave>[];

  @override
  Future<void> clear(String uid, String draftId) async {}

  @override
  Future<CheckInDisplayLabels> load(String uid, String draftId) async =>
      const CheckInDisplayLabels();

  @override
  Future<void> save(
    String uid,
    String draftId,
    CheckInDisplayLabels labels,
  ) async {
    saves.add((uid: uid, draftId: draftId, labels: labels));
    if (uid == 'alice') await aliceSave.future;
  }
}

final class _DraftRepository implements CheckInDraftRepository {
  _DraftRepository(this.value);

  CheckInDraft? value;
  Completer<void>? pendingSave;
  int saveCalls = 0;
  bool failNextSave = false;

  @override
  Future<void> clear(String uid) async => value = null;

  @override
  Future<CheckInDraft?> load(String uid) async => value;

  @override
  Future<void> save(String uid, CheckInDraft draft) async {
    saveCalls++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('draft save failed');
    }
    value = draft;
    final pending = pendingSave;
    if (pending != null) await pending.future;
  }
}

final class _PublicationRepository implements CheckInRepository {
  Object? error;
  int calls = 0;
  CheckInDraft? lastDraft;

  @override
  Future<void> delete(String checkInId) async {}

  @override
  Future<PublishCheckInResult> publish(CheckInDraft draft) async {
    calls++;
    lastDraft = draft;
    if (error case final failure?) throw failure;
    return PublishCheckInResult(draft.id, PublishCheckInStatus.created);
  }
}

final class _PublicationStateRepository
    implements CheckInPublicationRepository {
  @override
  Future<void> clear(String uid) async {}

  @override
  Future<CheckInPublicationMarker?> load(String uid) async => null;

  @override
  Future<void> save(String uid, CheckInPublicationMarker marker) async {}
}

final class _LabelRepository implements CheckInLabelRepository {
  final List<(String, String)> cleared = <(String, String)>[];
  final List<_LabelSave> saves = <_LabelSave>[];
  Completer<void>? pendingSave;
  Object? saveError;
  Object? loadError;
  CheckInDisplayLabels loadedLabels = const CheckInDisplayLabels();
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<void> clear(String uid, String draftId) async {
    cleared.add((uid, draftId));
  }

  @override
  Future<CheckInDisplayLabels> load(String uid, String draftId) async {
    loadCalls++;
    if (loadError case final error?) throw error;
    return loadedLabels;
  }

  @override
  Future<void> save(
    String uid,
    String draftId,
    CheckInDisplayLabels labels,
  ) async {
    saveCalls++;
    saves.add((uid: uid, draftId: draftId, labels: labels));
    if (saveError case final error?) throw error;
    final pending = pendingSave;
    if (pending != null) await pending.future;
  }
}

final class _PlaceRepository implements PlaceRepository {
  final List<(String, String, GeoPoint)> creates =
      <(String, String, GeoPoint)>[];

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    creates.add((name, address, location));
    return _place(placeId, name: name, address: address, location: location);
  }

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) async =>
      _place('place-new', name: name, address: address, location: location);

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) async =>
      const <Place>[];

  @override
  Stream<List<Place>> watchPlaces() => Stream.value(const <Place>[]);
}

Place _place(
  String id, {
  String name = 'Gelateria Aurora',
  String address = 'Via Roma 1',
  GeoPoint location = const GeoPoint(45, 9),
}) => Place(
  id: id,
  name: name,
  address: address,
  location: location,
  geohash: 'u0nd',
  createdAt: DateTime.utc(2026, 7, 15),
  addedByUid: 'alice',
);

final class _StorageGateway implements StorageObjectGateway {
  final List<String> putPaths = <String>[];

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    putPaths.add(path);
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async => null;
}

final class _PendingImagePicker extends ImagePickerPlatform {
  _PendingImagePicker(this.pending);

  final Completer<XFile?> pending;
  int calls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    calls++;
    return pending.future;
  }
}

final class _FlavorService implements FlavorService {
  _FlavorService({this.result, this.error, this.pending});

  final Flavor? result;
  final Object? error;
  final Completer<Flavor>? pending;
  int calls = 0;

  @override
  Future<Flavor> addFlavor(String name, {String? colorHex}) async {
    calls++;
    if (error case final failure?) throw failure;
    if (pending case final pending?) return pending.future;
    return result ?? Flavor(id: 'created-flavor', name: name);
  }
}

final class _DeniedLocationGateway implements LocationGateway {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<DeviceLocation> getCurrentLocation() async =>
      const DeviceLocation(latitude: 0, longitude: 0);

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
}

final class _MapAdapter implements PlaceMapSurfaceAdapter {
  const _MapAdapter(this.tapCoordinate);

  final GeoPoint tapCoordinate;

  @override
  Widget buildSurface(
    BuildContext context, {
    required GeoPoint initialCoordinate,
    required double initialZoom,
    required List<PlaceMapSurfaceMarker> markers,
    required ValueChanged<GeoPoint>? onMapTap,
    PlaceMapSurfaceController? controller,
  }) => GestureDetector(
    key: const ValueKey<String>('test-map-surface'),
    onTap: onMapTap == null ? null : () => onMapTap(tapCoordinate),
    child: const ColoredBox(color: Colors.grey),
  );
}

final class _RouterSession extends ChangeNotifier implements RouterAuthSession {
  @override
  String? get uid => 'alice';

  @override
  Future<void> signInWithGoogle() async {}
}

PublicProfile _profile(String uid, String displayName) =>
    PublicProfile.fromMap(<String, dynamic>{
      'uid': uid,
      'display_name': displayName,
      'display_name_lower': displayName.toLowerCase(),
      'username': uid,
      'username_lower': uid,
      'avatar_path': null,
      'bio': '',
      'city': 'Milano',
      'favorite_place_id': null,
      'favorite_flavor_id': null,
      'favorite_flavor_ids': const <String>[],
      'profile_visibility': 'friends',
      'searchable': true,
      'points': 0,
      'updated_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
    }, uid);

Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
