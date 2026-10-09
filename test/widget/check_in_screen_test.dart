import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/models/flavor.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/check_in_flow_provider.dart';
import 'package:gelatino/providers/flavors_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/gelato_types_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';
import 'package:gelatino/repositories/check_in_label_repository.dart';
import 'package:gelatino/repositories/check_in_publication_repository.dart';
import 'package:gelatino/repositories/check_in_repository.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/screens/check_in_screen.dart';
import 'package:gelatino/services/storage_service.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

Place _knownPlace() => Place(
  id: 'place-1',
  name: 'Gelateria nota',
  address: 'Via Fredda 1',
  location: const GeoPoint(45, 9),
  geohash: 'u0nd',
  createdAt: DateTime.utc(2026, 7, 15),
);

Flavor _knownFlavor() => Flavor(id: 'pistacchio', name: 'Pistacchio');

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';
  final now = DateTime.utc(2026, 7, 15, 12);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget app({
    CheckInDraft? draft,
    _DraftRepository? drafts,
    _PublicationRepository? publication,
    _PublicationStateRepository? publicationState,
    _StorageGateway? storage,
    _PlaceRepository? places,
    _LabelRepository? labels,
  }) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => _FakeUser('alice')),
        checkInDraftRepositoryProvider.overrideWithValue(
          drafts ?? _DraftRepository(draft),
        ),
        checkInRepositoryProvider.overrideWithValue(
          publication ?? _PublicationRepository(),
        ),
        checkInPublicationRepositoryProvider.overrideWithValue(
          publicationState ?? _PublicationStateRepository(),
        ),
        placeRepositoryProvider.overrideWithValue(places ?? _PlaceRepository()),
        storageServiceProvider.overrideWithValue(
          StorageService.forTesting(storage ?? _StorageGateway()),
        ),
        checkInIdGeneratorProvider.overrideWithValue(() => id),
        checkInClockProvider.overrideWithValue(() => now),
        if (labels != null)
          checkInLabelRepositoryProvider.overrideWithValue(labels),
        placesProvider.overrideWith(
          (ref) => Stream.value(<Place>[_knownPlace()]),
        ),
        flavorsProvider.overrideWith(
          (ref) => Stream.value(<Flavor>[_knownFlavor()]),
        ),
        gelatoTypesProvider.overrideWith(
          (ref) => Stream.value(defaultGelatoTypes),
        ),
        acceptedFriendProfilesProvider.overrideWithValue(
          const AsyncData(<PublicProfile>[]),
        ),
        timelineProjectionWaiterProvider.overrideWithValue((_, _) async {}),
      ],
      child: const MaterialApp(home: CheckInScreen()),
    );
  }

  testWidgets('renders five persisted steps and a clean route can pop', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    for (final label in const [
      'Foto',
      'Gelateria',
      'Il gelato',
      'Esperienza',
      'Condividi',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const Key('check-in-step-title-0')), findsOneWidget);
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isTrue,
    );
  });

  testWidgets('invalid Continue stays on Photo with a local error', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continua'));
    await tester.pump();

    expect(find.byKey(const Key('check-in-step-title-0')), findsOneWidget);
    expect(
      find.text('Aggiungi e carica una foto prima di continuare.'),
      findsOneWidget,
    );
  });

  testWidgets('gallery selection stages privately before advancing', (
    tester,
  ) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _MemoryImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final storage = _StorageGateway();
    await tester.pumpWidget(app(storage: storage));
    await tester.pumpAndSettle();

    await _pickFromGallery(tester);
    await tester.pumpAndSettle();

    expect(storage.putPaths, ['staging/alice/$id.jpg']);
    expect(find.text('Foto privata caricata'), findsOneWidget);
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('check-in-step-title-1')), findsOneWidget);
  });

  testWidgets('pending upload guards every exit after metadata save', (
    tester,
  ) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _MemoryImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final storage = _StorageGateway()..pendingPut = Completer<String>();
    await tester.pumpWidget(app(storage: storage));
    await tester.pumpAndSettle();

    await _pickFromGallery(tester);
    while (storage.putPaths.isEmpty) {
      await tester.pump();
    }
    await tester.pump();

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
          .widget<TextButton>(find.widgetWithText(TextButton, 'Chiudi'))
          .onPressed,
      isNull,
    );

    storage.pendingPut!.complete('staging/alice/$id.jpg');
    await tester.pumpAndSettle();
    expect(find.text('Foto privata caricata'), findsOneWidget);
  });

  testWidgets('failed upload retries the same private bytes then advances', (
    tester,
  ) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _MemoryImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final storage = _StorageGateway()..putError = StateError('network');
    await tester.pumpWidget(app(storage: storage));
    await tester.pumpAndSettle();

    await _pickFromGallery(tester);
    await tester.pumpAndSettle();
    expect(find.text('Riprova caricamento'), findsOneWidget);
    expect(storage.putPaths, hasLength(1));

    storage.putError = null;
    await tester.tap(find.text('Riprova caricamento'));
    await tester.pumpAndSettle();
    expect(storage.putPaths, hasLength(2));
    expect(find.text('Foto privata caricata'), findsOneWidget);
    expect(
      find.text('Caricamento della foto interrotto. Riprova.'),
      findsNothing,
    );

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('check-in-step-title-1')), findsOneWidget);
  });

  testWidgets('photo persistence failure stays handled in the screen', (
    tester,
  ) async {
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _MemoryImagePicker();
    addTearDown(() => ImagePickerPlatform.instance = previous);
    final drafts = _DraftRepository(null);
    await tester.pumpWidget(app(drafts: drafts));
    await tester.pumpAndSettle();
    drafts.saveError = StateError('disk');

    await _pickFromGallery(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('salvare l’ultima modifica'), findsOneWidget);
  });

  testWidgets('restored photo retry failure stays handled in the screen', (
    tester,
  ) async {
    final restored = CheckInDraft(
      id: id,
      currentStep: 0,
      localPhotoName: 'gelato.jpg',
      stagingObjectPath: 'staging/alice/$id.jpg',
      placeId: null,
      pendingPlace: null,
      gelatoTypeId: null,
      flavorIds: const [],
      rating: null,
      reviewText: '',
      taggedUserIds: const [],
      updatedAt: now,
    );
    final storage = _StorageGateway();
    await tester.pumpWidget(app(draft: restored, storage: storage));
    await tester.pumpAndSettle();
    storage.readError = StateError('network');

    await tester.ensureVisible(find.text('Riprova'));
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Impossibile verificare la foto privata.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'initial restored photo read failure is friendly retryable and blocking',
    (tester) async {
      final restored = CheckInDraft(
        id: id,
        currentStep: 0,
        localPhotoName: 'gelato.jpg',
        stagingObjectPath: 'staging/alice/$id.jpg',
        placeId: null,
        pendingPlace: null,
        gelatoTypeId: null,
        flavorIds: const <String>[],
        rating: null,
        reviewText: '',
        taggedUserIds: const <String>[],
        updatedAt: now,
      );
      final storage = _StorageGateway()
        ..readError = FirebaseException(
          plugin: 'firebase_storage',
          code: 'permission-denied',
          message: 'private bucket/users/alice path',
        );

      await tester.pumpWidget(app(draft: restored, storage: storage));
      await tester.pumpAndSettle();

      expect(
        find.text('Impossibile verificare la foto privata.'),
        findsOneWidget,
      );
      expect(find.text('Foto privata non trovata.'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Foto privata caricata'), findsNothing);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('private bucket'), findsNothing);

      await tester.tap(find.text('Continua'));
      await tester.pump();
      expect(find.byKey(const Key('check-in-step-title-0')), findsOneWidget);
      expect(
        find.text('Aggiungi e carica una foto prima di continuare.'),
        findsOneWidget,
      );

      storage
        ..readError = null
        ..readResult = _onePixelPng();
      final retry = find.widgetWithText(TextButton, 'Riprova');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Foto privata caricata'), findsOneWidget);
    },
  );

  testWidgets(
    'pending restored photo read keeps initialization locked until completion',
    (tester) async {
      for (final succeeds in <bool>[true, false]) {
        if (!succeeds) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
        final restored = CheckInDraft(
          id: id,
          currentStep: 0,
          localPhotoName: 'gelato.jpg',
          stagingObjectPath: 'staging/alice/$id.jpg',
          placeId: null,
          pendingPlace: null,
          gelatoTypeId: null,
          flavorIds: const <String>[],
          rating: null,
          reviewText: '',
          taggedUserIds: const <String>[],
          updatedAt: now,
        );
        final storage = _StorageGateway()
          ..pendingRead = Completer<Uint8List?>();

        await tester.pumpWidget(app(draft: restored, storage: storage));
        await tester.pump();
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Foto privata caricata'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Continua'), findsNothing);

        if (succeeds) {
          storage.pendingRead!.complete(_onePixelPng());
          await tester.pumpAndSettle();
          expect(find.text('Foto privata caricata'), findsOneWidget);
          expect(find.widgetWithText(FilledButton, 'Continua'), findsOneWidget);
        } else {
          storage.pendingRead!.completeError(
            FirebaseException(
              plugin: 'firebase_storage',
              code: 'permission-denied',
              message: 'private bucket path',
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Impossibile verificare la foto privata.'),
            findsOneWidget,
          );
          expect(find.text('Foto privata non trovata.'), findsOneWidget);
          expect(find.text('Riprova'), findsOneWidget);
          expect(find.textContaining('private bucket'), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'restored publish failure exposes retry and preserves the draft',
    (tester) async {
      final publication = _PublicationRepository()
        ..error = const CheckInRetryableFailure();
      final restored = CheckInDraft(
        id: id,
        currentStep: 4,
        localPhotoName: 'gelato.jpg',
        stagingObjectPath: 'staging/alice/$id.jpg',
        placeId: 'place-1',
        pendingPlace: null,
        gelatoTypeId: 'cono',
        flavorIds: const ['pistacchio'],
        rating: 5,
        reviewText: 'Ottimo',
        taggedUserIds: const [],
        updatedAt: now,
      );
      await tester.pumpWidget(
        app(
          draft: restored,
          publication: publication,
          storage: _StorageGateway(readResult: Uint8List.fromList([1, 2])),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();

      expect(find.text('Riprova'), findsOneWidget);
      expect(find.textContaining('Pubblicazione interrotta'), findsOneWidget);
      publication.error = null;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Check-in pubblicato'), findsOneWidget);
      expect(publication.calls, 2);
    },
  );

  testWidgets('restored calling outbox labels the final action as retry', (
    tester,
  ) async {
    final publication = _PublicationRepository();
    final publicationState = _PublicationStateRepository()
      ..marker = CheckInPublicationMarker.calling(id);
    final restored = CheckInDraft(
      id: id,
      currentStep: 4,
      localPhotoName: 'gelato.jpg',
      stagingObjectPath: 'staging/alice/$id.jpg',
      placeId: 'place-1',
      pendingPlace: null,
      gelatoTypeId: 'cono',
      flavorIds: const ['pistacchio'],
      rating: 5,
      reviewText: 'Ottimo',
      taggedUserIds: const [],
      updatedAt: now,
    );
    await tester.pumpWidget(
      app(
        draft: restored,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: _onePixelPng()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Riprova'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pubblica'), findsNothing);
  });

  testWidgets(
    'published pending clear freezes editor and retry skips callable',
    (tester) async {
      final publication = _PublicationRepository();
      final drafts = _DraftRepository(
        CheckInDraft(
          id: id,
          currentStep: 4,
          localPhotoName: 'gelato.jpg',
          stagingObjectPath: 'staging/alice/$id.jpg',
          placeId: 'place-1',
          pendingPlace: null,
          gelatoTypeId: 'cono',
          flavorIds: const ['pistacchio'],
          rating: 5,
          reviewText: 'Ottimo',
          taggedUserIds: const [],
          updatedAt: now,
        ),
      )..clearError = StateError('disk');
      await tester.pumpWidget(
        app(
          drafts: drafts,
          publication: publication,
          storage: _StorageGateway(readResult: _onePixelPng()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();

      expect(find.text('Riprova pulizia'), findsOneWidget);
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isFalse,
      );
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byKey(const Key('check-in-editor-lock')),
            )
            .absorbing,
        isTrue,
      );
      expect(publication.calls, 1);

      drafts.clearError = null;
      await tester.tap(find.text('Riprova pulizia'));
      await tester.pumpAndSettle();

      expect(find.text('Check-in pubblicato'), findsOneWidget);
      expect(publication.calls, 1);
      expect(drafts.clearCalls, 2);
    },
  );

  testWidgets(
    'published orphan exposes cleanup recovery after container recreation',
    (tester) async {
      final drafts = _DraftRepository(
        CheckInDraft(
          id: id,
          currentStep: 4,
          localPhotoName: 'gelato.jpg',
          stagingObjectPath: 'staging/alice/$id.jpg',
          placeId: 'place-1',
          pendingPlace: null,
          gelatoTypeId: 'cono',
          flavorIds: const ['pistacchio'],
          rating: 5,
          reviewText: 'Ottimo',
          taggedUserIds: const [],
          updatedAt: now,
        ),
      );
      final publication = _PublicationRepository();
      final publicationState = _PublicationStateRepository()
        ..clearError = StateError('disk');
      final labels = _LabelRepository();

      await tester.pumpWidget(
        app(
          drafts: drafts,
          publication: publication,
          publicationState: publicationState,
          labels: labels,
          storage: _StorageGateway(readResult: _onePixelPng()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pubblica'));
      await tester.pumpAndSettle();
      expect(drafts.value, isNull);
      expect(publicationState.marker?.phase, CheckInPublicationPhase.published);
      expect(publication.calls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        app(
          drafts: drafts,
          publication: publication,
          publicationState: publicationState,
          labels: labels,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completa pulizia'), findsOneWidget);
      expect(find.text('Check-in già pubblicato'), findsOneWidget);
      expect(find.textContaining('stato locale'), findsOneWidget);

      publicationState
        ..clearError = null
        ..pendingClear = Completer<void>();
      await tester.tap(find.text('Completa pulizia'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(publication.calls, 1);

      publicationState.pendingClear!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Check-in pubblicato'), findsOneWidget);
      expect(publication.calls, 1);
      expect(publicationState.marker, isNull);
      expect(labels.cleared, <(String, String)>[('alice', id)]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        app(
          drafts: drafts,
          publication: publication,
          publicationState: publicationState,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('check-in-step-title-0')), findsOneWidget);
      expect(drafts.value?.currentStep, 0);
      expect(publication.calls, 1);
    },
  );

  testWidgets(
    'slow place resolution freezes fields navigation and duplicate continue',
    (tester) async {
      final places = _PlaceRepository()..pending = Completer<Place>();
      final restored = CheckInDraft(
        id: id,
        currentStep: 1,
        localPhotoName: 'gelato.jpg',
        stagingObjectPath: 'staging/alice/$id.jpg',
        placeId: null,
        pendingPlace: PendingPlaceDraft(
          name: 'Nuova',
          address: 'Via 1',
          latitude: 45,
          longitude: 9,
        ),
        gelatoTypeId: null,
        flavorIds: const [],
        rating: null,
        reviewText: '',
        taggedUserIds: const [],
        updatedAt: now,
      );
      await tester.pumpWidget(app(draft: restored, places: places));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continua'));
      while (places.calls == 0) {
        await tester.pump();
      }
      await tester.pump();

      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .onChanged,
        isNull,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Indietro'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(
                  const ValueKey<String>('check-in-sticky-navigation'),
                ),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
        isFalse,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('check-in-sticky-navigation')),
          matching: find.byType(FilledButton),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(places.calls, 1);

      places.pending!.complete(places.result('user_place_$id'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('check-in-step-title-2')), findsOneWidget);
      expect(places.calls, 1);
    },
  );
}

final class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get displayName => 'Alice';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DraftRepository implements CheckInDraftRepository {
  _DraftRepository(this.value);

  CheckInDraft? value;
  Object? saveError;
  Object? clearError;
  int clearCalls = 0;

  @override
  Future<void> clear(String uid) async {
    clearCalls++;
    if (clearError case final error?) throw error;
    value = null;
  }

  @override
  Future<CheckInDraft?> load(String uid) async => value;

  @override
  Future<void> save(String uid, CheckInDraft draft) async {
    if (saveError case final error?) throw error;
    value = draft;
  }
}

final class _PublicationRepository implements CheckInRepository {
  Object? error;
  int calls = 0;

  @override
  Future<void> delete(String checkInId) async {}

  @override
  Future<PublishCheckInResult> publish(CheckInDraft draft) async {
    calls++;
    if (error case final error?) throw error;
    return PublishCheckInResult(draft.id, PublishCheckInStatus.created);
  }
}

final class _PublicationStateRepository
    implements CheckInPublicationRepository {
  CheckInPublicationMarker? marker;
  Object? clearError;
  Completer<void>? pendingClear;
  int clearCalls = 0;

  @override
  Future<void> clear(String uid) async {
    clearCalls++;
    if (clearError case final error?) throw error;
    final pending = pendingClear;
    if (pending != null) await pending.future;
    marker = null;
  }

  @override
  Future<CheckInPublicationMarker?> load(String uid) async => marker;

  @override
  Future<void> save(String uid, CheckInPublicationMarker marker) async {
    this.marker = marker;
  }
}

final class _LabelRepository implements CheckInLabelRepository {
  final List<(String, String)> cleared = <(String, String)>[];

  @override
  Future<void> clear(String uid, String draftId) async {
    cleared.add((uid, draftId));
  }

  @override
  Future<CheckInDisplayLabels> load(String uid, String draftId) async =>
      const CheckInDisplayLabels();

  @override
  Future<void> save(
    String uid,
    String draftId,
    CheckInDisplayLabels labels,
  ) async {}
}

final class _PlaceRepository implements PlaceRepository {
  Completer<Place>? pending;
  int calls = 0;

  Place result(String id) => Place(
    id: id,
    name: 'Nuova',
    address: 'Via 1',
    location: const GeoPoint(45, 9),
    geohash: 'u0nd',
    createdAt: DateTime.utc(2026, 7, 15),
    addedByUid: 'alice',
  );

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) {
    calls++;
    return pending?.future ?? Future<Place>.value(result(placeId));
  }

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) => Future<Place>.value(result('place'));

  @override
  Future<List<Place>> readPlaces(List<String> placeIds) async => const [];

  @override
  Stream<List<Place>> watchPlaces() => Stream.value(const []);
}

final class _StorageGateway implements StorageObjectGateway {
  _StorageGateway({this.readResult});

  Uint8List? readResult;
  Object? readError;
  Completer<Uint8List?>? pendingRead;
  Object? putError;
  Completer<String>? pendingPut;
  final List<String> putPaths = [];

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    putPaths.add(path);
    if (putError case final error?) throw error;
    final pending = pendingPut;
    if (pending != null) return pending.future;
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    if (readError case final error?) throw error;
    final pending = pendingRead;
    if (pending != null) return pending.future;
    return readResult;
  }
}

/// Picks through the fake picker and accepts the default framing.
Future<void> _pickFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('Galleria'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Usa questa inquadratura'));
  await tester.pump();
}

final class _MemoryImagePicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
    name: 'gelato.png',
    mimeType: 'image/png',
  );
}

Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
