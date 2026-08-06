import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/check_in_flow_provider.dart';
import 'package:gelatino/e2e/emulator_photo_fixture.dart';
import 'package:gelatino/providers/location_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/repositories/check_in_draft_repository.dart';
import 'package:gelatino/repositories/check_in_publication_repository.dart';
import 'package:gelatino/repositories/check_in_repository.dart';
import 'package:gelatino/repositories/place_repository.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:image/image.dart' as img;

final _activeUidProvider = NotifierProvider<_ActiveUidNotifier, String?>(
  _ActiveUidNotifier.new,
);

final class _ActiveUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void setUid(String? uid) => state = uid;
}

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';
  final now = DateTime.utc(2026, 7, 15, 10);

  ProviderContainer container({
    required _DraftRepository drafts,
    required _CheckInRepository publication,
    required StorageObjectGateway storage,
    _PublicationStateRepository? publicationState,
    _PlaceRepository? places,
    _LocationGateway? location,
  }) => ProviderContainer(
    overrides: [
      currentUidProvider.overrideWith((ref) => ref.watch(_activeUidProvider)),
      checkInDraftRepositoryProvider.overrideWithValue(drafts),
      checkInPublicationRepositoryProvider.overrideWithValue(
        publicationState ?? _PublicationStateRepository(),
      ),
      checkInRepositoryProvider.overrideWithValue(publication),
      storageServiceProvider.overrideWithValue(
        StorageService.forTesting(storage),
      ),
      placeRepositoryProvider.overrideWithValue(places ?? _PlaceRepository()),
      deviceLocationServiceProvider.overrideWithValue(
        DeviceLocationService(location ?? _LocationGateway()),
      ),
      checkInIdGeneratorProvider.overrideWithValue(() => id),
      checkInClockProvider.overrideWithValue(() => now),
    ],
  );

  Future<CheckInFlowState> initialized(ProviderContainer container) async {
    final subscription = container.listen(
      checkInFlowProvider('alice'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    for (var attempt = 0; attempt < 20; attempt++) {
      final state = container.read(checkInFlowProvider('alice'));
      if (!state.isInitializing) return state;
      await Future<void>.delayed(Duration.zero);
    }
    fail('flow did not initialize');
  }

  test('creates and persists one clean step-zero draft', () async {
    final drafts = _DraftRepository();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: _StorageGateway(),
    );
    addTearDown(scope.dispose);

    final state = await initialized(scope);

    expect(state.draft?.id, id);
    expect(state.draft?.currentStep, 0);
    expect(state.isDirty, isFalse);
    expect(drafts.saved.single.id, id);
  });

  test('retryDraftSave retries a failed latest snapshot', () async {
    final drafts = _DraftRepository(initial: _completeDraft(id, now));
    final publication = _CheckInRepository();
    final scope = container(
      drafts: drafts,
      publication: publication,
      storage: _StorageGateway(readResult: Uint8List.fromList([1])),
    );
    addTearDown(scope.dispose);
    await initialized(scope);
    final controller = scope.read(checkInFlowProvider('alice').notifier);

    drafts.failNextSave = true;
    await expectLater(
      controller.setTaggedUsers(const <String>['bob', 'carol']),
      throwsA(isA<CheckInFlowFailure>()),
    );
    var state = scope.read(checkInFlowProvider('alice'));
    expect(state.isDirty, isTrue);
    expect(state.failure?.kind, CheckInFlowFailureKind.persistence);
    expect(drafts.saveCalls, 1);

    await controller.retryDraftSave();

    state = scope.read(checkInFlowProvider('alice'));
    expect(drafts.saveCalls, 2);
    expect(drafts.saved.last.taggedUserIds, const <String>['bob', 'carol']);
    expect(state.isDirty, isFalse);
    expect(state.failure, isNull);

    await controller.publish();
    expect(publication.publishCalls, 1);
    expect(drafts.saveCalls, 2);
  });

  test('photo uploads immediately and retry reuses ID and path', () async {
    final drafts = _DraftRepository();
    final storage = _StorageGateway();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: storage,
    );
    addTearDown(scope.dispose);
    await initialized(scope);

    await scope
        .read(checkInFlowProvider('alice').notifier)
        .selectPhoto(_onePixelPng(), 'gelato.png');

    final state = scope.read(checkInFlowProvider('alice'));
    expect(storage.putPaths, ['staging/alice/$id.jpg']);
    expect(state.draft?.stagingObjectPath, 'staging/alice/$id.jpg');
    expect(state.isDirty, isFalse);

    storage.failNextPut = true;
    await scope
        .read(checkInFlowProvider('alice').notifier)
        .selectPhoto(_onePixelPng(), 'gelato-2.png');
    expect(scope.read(checkInFlowProvider('alice')).failure, isNotNull);
    await scope.read(checkInFlowProvider('alice').notifier).retryPhotoUpload();
    expect(scope.read(checkInFlowProvider('alice')).failure, isNull);
    expect(storage.putPaths.toSet(), {'staging/alice/$id.jpg'});
  });

  test('E2E JPEG fixture uses the real staged-photo pipeline', () async {
    final drafts = _DraftRepository();
    final storage = _StorageGateway();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: storage,
    );
    addTearDown(scope.dispose);
    await initialized(scope);

    await scope
        .read(checkInFlowProvider('alice').notifier)
        .selectPhoto(EmulatorPhotoFixture.bytes, EmulatorPhotoFixture.fileName);

    expect(storage.putPaths, ['staging/alice/$id.jpg']);
    expect(
      scope.read(checkInFlowProvider('alice')).draft?.localPhotoName,
      EmulatorPhotoFixture.fileName,
    );
  });

  test(
    'newer photo waits for older upload and is the final stored object',
    () async {
      final drafts = _DraftRepository();
      final storage = _ControlledStorageGateway()
        ..firstPutGate = Completer<void>();
      final scope = container(
        drafts: drafts,
        publication: _CheckInRepository(),
        storage: storage,
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);
      final firstBytes = _solidPng(red: 255, green: 0, blue: 0);
      final secondBytes = _solidPng(red: 0, green: 0, blue: 255);

      final first = notifier.selectPhoto(firstBytes, 'first.png');
      while (storage.putBytes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final second = notifier.selectPhoto(secondBytes, 'second.png');
      await Future<void>.delayed(Duration.zero);

      expect(storage.putBytes, hasLength(1));
      storage.firstPutGate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(storage.putBytes, hasLength(2));
      expect(
        scope.read(checkInFlowProvider('alice')).photoBytes,
        orderedEquals(secondBytes),
      );
      expect(
        scope.read(checkInFlowProvider('alice')).draft?.stagingObjectPath,
        'staging/alice/$id.jpg',
      );
      final stored = img.decodeImage(storage.storedBytes!);
      expect(stored, isNotNull);
      final pixel = stored!.getPixel(0, 0);
      expect(pixel.b, greaterThan(pixel.r));
    },
  );

  test(
    'remove invalidates an upload completion without restoring photo',
    () async {
      final drafts = _DraftRepository();
      final storage = _ControlledStorageGateway()
        ..firstPutGate = Completer<void>();
      final scope = container(
        drafts: drafts,
        publication: _CheckInRepository(),
        storage: storage,
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);

      final upload = notifier.selectPhoto(_onePixelPng(), 'gelato.png');
      while (storage.putBytes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await notifier.removePhoto();
      storage.firstPutGate!.complete();
      await upload;

      final state = scope.read(checkInFlowProvider('alice'));
      expect(state.photoBytes, isNull);
      expect(state.draft?.localPhotoName, isNull);
      expect(state.draft?.stagingObjectPath, isNull);
      expect(drafts.saved.last.stagingObjectPath, isNull);
    },
  );

  test('remove invalidates a restored authenticated read completion', () async {
    final restored = _completeDraft(id, now).copyWith(currentStep: 0);
    final drafts = _DraftRepository(initial: restored);
    final storage = _ControlledStorageGateway()
      ..readGate = Completer<Uint8List?>();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: storage,
    );
    addTearDown(scope.dispose);
    final subscription = scope.listen(
      checkInFlowProvider('alice'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    while (scope.read(checkInFlowProvider('alice')).draft == null) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(scope.read(checkInFlowProvider('alice')).isInitializing, isTrue);
    final notifier = scope.read(checkInFlowProvider('alice').notifier);

    await notifier.removePhoto();
    storage.readGate!.complete(_onePixelPng());
    await Future<void>.delayed(Duration.zero);

    final state = scope.read(checkInFlowProvider('alice'));
    expect(state.photoBytes, isNull);
    expect(state.photoMissing, isFalse);
    expect(state.isInitializing, isFalse);
    expect(state.draft?.stagingObjectPath, isNull);
  });

  test(
    'publish failure preserves draft and retry clears only after success',
    () async {
      final complete = _completeDraft(id, now);
      final drafts = _DraftRepository(initial: complete);
      final publicationState = _PublicationStateRepository();
      final publication = _CheckInRepository()
        ..error = const CheckInRetryableFailure();
      final scope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1, 2])),
      );
      addTearDown(scope.dispose);
      await initialized(scope);

      await expectLater(
        scope.read(checkInFlowProvider('alice').notifier).publish(),
        throwsA(isA<CheckInFlowFailure>()),
      );
      expect(scope.read(checkInFlowProvider('alice')).draft, complete);
      expect(
        scope.read(checkInFlowProvider('alice')).publicationCallingPendingRetry,
        isTrue,
      );
      expect(
        publicationState.marker,
        const CheckInPublicationMarker.calling(id),
      );
      expect(drafts.clearCalls, 0);

      final response = Completer<PublishCheckInResult>();
      publication
        ..error = null
        ..pending = response;
      final retry = scope.read(checkInFlowProvider('alice').notifier).publish();
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(checkInFlowProvider('alice')).draft?.id, id);
      expect(drafts.clearCalls, 0);
      response.complete(
        const PublishCheckInResult(id, PublishCheckInStatus.existing),
      );
      await retry;

      expect(drafts.clearCalls, 1);
      expect(publicationState.marker, isNull);
      expect(scope.read(checkInFlowProvider('alice')).draft, isNull);
      expect(scope.read(checkInFlowProvider('alice')).published, isTrue);
    },
  );

  for (final definitive in <({String name, CheckInFailure failure})>[
    (name: 'authentication', failure: const CheckInAuthenticationFailure()),
    (name: 'permission', failure: const CheckInPermissionFailure()),
    (name: 'validation', failure: const CheckInValidationFailure('invalid')),
    (name: 'media missing', failure: const CheckInMediaMissingFailure()),
    (name: 'precondition', failure: const CheckInPreconditionFailure()),
  ]) {
    test(
      '${definitive.name} failure clears failed marker before unlocking editor',
      () async {
        final events = <String>[];
        final drafts = _DraftRepository(initial: _completeDraft(id, now));
        final publication = _CheckInRepository()..error = definitive.failure;
        final publicationState = _PublicationStateRepository(events: events);
        final scope = container(
          drafts: drafts,
          publication: publication,
          publicationState: publicationState,
          storage: _StorageGateway(readResult: Uint8List.fromList([1])),
        );
        addTearDown(scope.dispose);
        await initialized(scope);

        await expectLater(
          scope.read(checkInFlowProvider('alice').notifier).publish(),
          throwsA(isA<CheckInFlowFailure>()),
        );

        final state = scope.read(checkInFlowProvider('alice'));
        expect(publication.publishCalls, 1);
        expect(
          publicationState.saved.map((marker) => marker.phase),
          <CheckInPublicationPhase>[
            CheckInPublicationPhase.calling,
            CheckInPublicationPhase.failed,
          ],
        );
        expect(publicationState.marker, isNull);
        expect(events, <String>[
          'outbox.save.calling',
          'outbox.save.failed',
          'outbox.clear',
        ]);
        expect(state.publicationCallingPendingRetry, isFalse);
        expect(state.publicationFailedPendingClear, isFalse);
        expect(state.isEditorLocked, isFalse);
        expect(state.failure?.kind, CheckInFlowFailureKind.publication);
        expect(state.draft?.id, id);
        expect(drafts.clearCalls, 0);
      },
    );
  }

  for (final ambiguous in <({String name, CheckInFailure failure})>[
    (name: 'retryable', failure: const CheckInRetryableFailure()),
    (name: 'remote', failure: const CheckInRemoteFailure()),
    (
      name: 'protocol',
      failure: const CheckInProtocolFailure('invalid response'),
    ),
  ]) {
    test('${ambiguous.name} failure stays calling and locked', () async {
      final publication = _CheckInRepository()..error = ambiguous.failure;
      final publicationState = _PublicationStateRepository();
      final scope = container(
        drafts: _DraftRepository(initial: _completeDraft(id, now)),
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      addTearDown(scope.dispose);
      await initialized(scope);

      await expectLater(
        scope.read(checkInFlowProvider('alice').notifier).publish(),
        throwsA(isA<CheckInFlowFailure>()),
      );

      final state = scope.read(checkInFlowProvider('alice'));
      expect(publication.publishCalls, 1);
      expect(publicationState.marker?.phase, CheckInPublicationPhase.calling);
      expect(state.publicationCallingPendingRetry, isTrue);
      expect(state.isEditorLocked, isTrue);
      expect(publicationState.clearCalls, 0);
    });
  }

  test(
    'failed clear restore retries only marker cleanup then unlocks editor',
    () async {
      final drafts = _DraftRepository(initial: _completeDraft(id, now));
      final publication = _CheckInRepository()
        ..error = const CheckInPermissionFailure();
      final publicationState = _PublicationStateRepository()
        ..clearError = StateError('disk');
      final firstScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      await initialized(firstScope);

      await expectLater(
        firstScope.read(checkInFlowProvider('alice').notifier).publish(),
        throwsA(isA<CheckInFlowFailure>()),
      );
      expect(publicationState.marker?.phase, CheckInPublicationPhase.failed);
      expect(
        firstScope
            .read(checkInFlowProvider('alice'))
            .publicationFailedPendingClear,
        isTrue,
      );
      expect(
        firstScope.read(checkInFlowProvider('alice')).isEditorLocked,
        isTrue,
      );
      expect(publication.publishCalls, 1);
      firstScope.dispose();

      final secondScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      addTearDown(secondScope.dispose);
      final restored = await initialized(secondScope);
      expect(restored.publicationFailedPendingClear, isTrue);
      expect(restored.isEditorLocked, isTrue);

      publicationState.clearError = null;
      await expectLater(
        secondScope.read(checkInFlowProvider('alice').notifier).publish(),
        throwsA(isA<CheckInFlowFailure>()),
      );

      final unlocked = secondScope.read(checkInFlowProvider('alice'));
      expect(publication.publishCalls, 1);
      expect(publicationState.marker, isNull);
      expect(unlocked.publicationFailedPendingClear, isFalse);
      expect(unlocked.isEditorLocked, isFalse);
      await secondScope
          .read(checkInFlowProvider('alice').notifier)
          .setReviewText('Corretto');
      expect(
        secondScope.read(checkInFlowProvider('alice')).draft?.reviewText,
        'Corretto',
      );
    },
  );

  test('failed marker write stays calling and fail-closed', () async {
    final publication = _CheckInRepository()
      ..error = const CheckInValidationFailure('invalid');
    final publicationState = _PublicationStateRepository()
      ..saveErrorForPhase = CheckInPublicationPhase.failed;
    final scope = container(
      drafts: _DraftRepository(initial: _completeDraft(id, now)),
      publication: publication,
      publicationState: publicationState,
      storage: _StorageGateway(readResult: Uint8List.fromList([1])),
    );
    addTearDown(scope.dispose);
    await initialized(scope);

    await expectLater(
      scope.read(checkInFlowProvider('alice').notifier).publish(),
      throwsA(isA<CheckInFlowFailure>()),
    );

    final state = scope.read(checkInFlowProvider('alice'));
    expect(publication.publishCalls, 1);
    expect(publicationState.marker?.phase, CheckInPublicationPhase.calling);
    expect(state.publicationCallingPendingRetry, isTrue);
    expect(state.publicationFailedPendingClear, isFalse);
    expect(state.isEditorLocked, isTrue);
    expect(state.failure?.kind, CheckInFlowFailureKind.persistence);
    expect(publicationState.clearCalls, 0);
  });

  test('clear failure stays visible and does not silently restart', () async {
    final drafts = _DraftRepository(initial: _completeDraft(id, now))
      ..clearError = StateError('disk');
    final publication = _CheckInRepository();
    final publicationState = _PublicationStateRepository();
    final scope = container(
      drafts: drafts,
      publication: publication,
      publicationState: publicationState,
      storage: _StorageGateway(readResult: Uint8List.fromList([1])),
    );
    addTearDown(scope.dispose);
    await initialized(scope);
    final notifier = scope.read(checkInFlowProvider('alice').notifier);

    await expectLater(notifier.publish(), throwsA(isA<CheckInFlowFailure>()));

    var state = scope.read(checkInFlowProvider('alice'));
    expect(state.draft?.id, id);
    expect(state.published, isFalse);
    expect(state.publishedPendingClear, isTrue);
    expect(publicationState.marker?.phase, CheckInPublicationPhase.published);
    expect(state.failure, isNotNull);
    expect(publication.publishCalls, 1);

    await expectLater(
      notifier.setReviewText('Modifica vietata'),
      throwsA(isA<CheckInFlowFailure>()),
    );
    await expectLater(
      notifier.selectExistingPlace('other-place'),
      throwsA(isA<CheckInFlowFailure>()),
    );
    await expectLater(
      notifier.removePhoto(),
      throwsA(isA<CheckInFlowFailure>()),
    );
    expect(scope.read(checkInFlowProvider('alice')).draft, state.draft);

    drafts.clearError = null;
    await notifier.publish();

    state = scope.read(checkInFlowProvider('alice'));
    expect(publication.publishCalls, 1);
    expect(drafts.clearCalls, 2);
    expect(state.publishedPendingClear, isFalse);
    expect(state.published, isTrue);
    expect(state.draft, isNull);
    expect(publicationState.marker, isNull);
  });

  test('calling marker failure prevents every backend invocation', () async {
    final drafts = _DraftRepository(initial: _completeDraft(id, now));
    final publication = _CheckInRepository();
    final publicationState = _PublicationStateRepository()
      ..saveError = StateError('disk');
    final scope = container(
      drafts: drafts,
      publication: publication,
      publicationState: publicationState,
      storage: _StorageGateway(readResult: Uint8List.fromList([1])),
    );
    addTearDown(scope.dispose);
    await initialized(scope);

    await expectLater(
      scope.read(checkInFlowProvider('alice').notifier).publish(),
      throwsA(isA<CheckInFlowFailure>()),
    );

    final state = scope.read(checkInFlowProvider('alice'));
    expect(publication.publishCalls, 0);
    expect(publicationState.marker, isNull);
    expect(state.publicationCallingPendingRetry, isFalse);
    expect(state.isPublishing, isFalse);
    expect(state.draft?.id, id);
  });

  test(
    'recreate after clear failure restores published cleanup without callable',
    () async {
      final events = <String>[];
      final drafts = _DraftRepository(
        initial: _completeDraft(id, now),
        events: events,
      )..clearError = StateError('disk');
      final publication = _CheckInRepository();
      final publicationState = _PublicationStateRepository(events: events);
      final firstScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      await initialized(firstScope);

      await expectLater(
        firstScope.read(checkInFlowProvider('alice').notifier).publish(),
        throwsA(isA<CheckInFlowFailure>()),
      );
      firstScope.dispose();

      final secondScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      addTearDown(secondScope.dispose);
      final restored = await initialized(secondScope);
      expect(restored.publishedPendingClear, isTrue);
      expect(restored.draft?.id, id);
      await expectLater(
        secondScope
            .read(checkInFlowProvider('alice').notifier)
            .setReviewText('vietata'),
        throwsA(isA<CheckInFlowFailure>()),
      );

      drafts.clearError = null;
      await secondScope.read(checkInFlowProvider('alice').notifier).publish();

      expect(publication.publishCalls, 1);
      expect(drafts.clearCalls, 2);
      expect(publicationState.clearCalls, 1);
      expect(events.sublist(events.length - 2), <String>[
        'draft.clear',
        'outbox.clear',
      ]);
      expect(secondScope.read(checkInFlowProvider('alice')).published, isTrue);
    },
  );

  test(
    'recreate from calling marker retries the idempotent callable',
    () async {
      final drafts = _DraftRepository(initial: _completeDraft(id, now));
      final publicationState = _PublicationStateRepository();
      final firstResponse = Completer<PublishCheckInResult>();
      final publication = _CheckInRepository()..pending = firstResponse;
      final firstScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      await initialized(firstScope);

      final firstPublish = firstScope
          .read(checkInFlowProvider('alice').notifier)
          .publish();
      while (publicationState.marker?.phase !=
              CheckInPublicationPhase.calling ||
          publication.publishCalls != 1) {
        await Future<void>.delayed(Duration.zero);
      }
      firstScope.dispose();

      final secondResponse = Completer<PublishCheckInResult>();
      publication.pending = secondResponse;
      final secondScope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(readResult: Uint8List.fromList([1])),
      );
      addTearDown(secondScope.dispose);
      final restored = await initialized(secondScope);
      expect(restored.publicationCallingPendingRetry, isTrue);
      expect(restored.isEditorLocked, isTrue);

      final retry = secondScope
          .read(checkInFlowProvider('alice').notifier)
          .publish();
      while (publication.publishCalls != 2) {
        await Future<void>.delayed(Duration.zero);
      }
      secondResponse.complete(
        const PublishCheckInResult(id, PublishCheckInStatus.existing),
      );
      await retry;
      firstResponse.complete(
        const PublishCheckInResult(id, PublishCheckInStatus.created),
      );
      await firstPublish;

      expect(publication.publishCalls, 2);
      expect(secondScope.read(checkInFlowProvider('alice')).published, isTrue);
      expect(publicationState.marker, isNull);
    },
  );

  test(
    'orphan published marker cleans up without creating a new draft',
    () async {
      final drafts = _DraftRepository();
      final publication = _CheckInRepository();
      final publicationState = _PublicationStateRepository(
        initial: const CheckInPublicationMarker.published(
          id,
          PublishCheckInResult(id, PublishCheckInStatus.created),
        ),
      );
      final scope = container(
        drafts: drafts,
        publication: publication,
        publicationState: publicationState,
        storage: _StorageGateway(),
      );
      addTearDown(scope.dispose);

      final restored = await initialized(scope);
      expect(restored.publishedPendingClear, isTrue);
      expect(restored.draft, isNull);
      expect(drafts.saved, isEmpty);
      await scope.read(checkInFlowProvider('alice').notifier).publish();

      expect(publication.publishCalls, 0);
      expect(publicationState.marker, isNull);
      expect(scope.read(checkInFlowProvider('alice')).published, isTrue);
    },
  );

  test('orphan calling marker fails closed without creating a draft', () async {
    final drafts = _DraftRepository();
    final publication = _CheckInRepository();
    final publicationState = _PublicationStateRepository(
      initial: const CheckInPublicationMarker.calling(id),
    );
    final scope = container(
      drafts: drafts,
      publication: publication,
      publicationState: publicationState,
      storage: _StorageGateway(),
    );
    addTearDown(scope.dispose);

    final restored = await initialized(scope);
    expect(restored.publicationCallingPendingRetry, isTrue);
    expect(restored.draft, isNull);
    expect(restored.failure, isNotNull);
    expect(drafts.saved, isEmpty);
    await expectLater(
      scope.read(checkInFlowProvider('alice').notifier).publish(),
      throwsA(isA<CheckInFlowFailure>()),
    );
    expect(publication.publishCalls, 0);
  });

  test('mismatched calling marker never publishes another draft', () async {
    const otherId = 'QRSTUVWXYZABCDEFGHIJ';
    final drafts = _DraftRepository(initial: _completeDraft(otherId, now));
    final publication = _CheckInRepository();
    final publicationState = _PublicationStateRepository(
      initial: const CheckInPublicationMarker.calling(id),
    );
    final scope = container(
      drafts: drafts,
      publication: publication,
      publicationState: publicationState,
      storage: _StorageGateway(),
    );
    addTearDown(scope.dispose);

    final restored = await initialized(scope);
    expect(restored.publicationCallingPendingRetry, isTrue);
    expect(restored.draft?.id, otherId);
    await expectLater(
      scope.read(checkInFlowProvider('alice').notifier).publish(),
      throwsA(isA<CheckInFlowFailure>()),
    );
    expect(publication.publishCalls, 0);
  });

  test(
    'explicit map location skips GPS and persists place before publish',
    () async {
      final drafts = _DraftRepository();
      final places = _PlaceRepository();
      final location = _LocationGateway();
      final scope = container(
        drafts: drafts,
        publication: _CheckInRepository(),
        storage: _StorageGateway(),
        places: places,
        location: location,
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);
      await notifier.setPendingPlace(
        PendingPlaceDraft(
          name: 'Nuova',
          address: 'Via 1',
          latitude: 45.46,
          longitude: 9.19,
        ),
      );

      await notifier.resolvePendingPlace();

      expect(location.calls, 0);
      expect(places.calls, 1);
      expect(
        scope.read(checkInFlowProvider('alice')).draft?.placeId,
        'user_place_$id',
      );
      expect(drafts.saved.last.placeId, 'user_place_$id');
      await notifier.resolvePendingPlace();
      expect(places.calls, 1);
    },
  );

  test('double place resolution shares one create-or-read operation', () async {
    final places = _PlaceRepository()..pending = Completer<Place>();
    final scope = container(
      drafts: _DraftRepository(),
      publication: _CheckInRepository(),
      storage: _StorageGateway(),
      places: places,
    );
    addTearDown(scope.dispose);
    await initialized(scope);
    final notifier = scope.read(checkInFlowProvider('alice').notifier);
    await notifier.setPendingPlace(
      PendingPlaceDraft(
        name: 'Nuova',
        address: 'Via 1',
        latitude: 45,
        longitude: 9,
      ),
    );

    final first = notifier.resolvePendingPlace();
    final second = notifier.resolvePendingPlace();

    expect(identical(first, second), isTrue);
    expect(scope.read(checkInFlowProvider('alice')).isResolvingPlace, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(places.calls, 1);
    places.pending!.complete(places.result('user_place_$id'));
    expect(await first, 'user_place_$id');
    expect(await second, 'user_place_$id');
    expect(scope.read(checkInFlowProvider('alice')).isResolvingPlace, isFalse);
  });

  test(
    'pending place edit is blocked during an in-flight resolution',
    () async {
      final places = _PlaceRepository()..pending = Completer<Place>();
      final scope = container(
        drafts: _DraftRepository(),
        publication: _CheckInRepository(),
        storage: _StorageGateway(),
        places: places,
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);
      await notifier.setPendingPlace(
        PendingPlaceDraft(
          name: 'Prima',
          address: 'Via 1',
          latitude: 45,
          longitude: 9,
        ),
      );

      final resolution = notifier.resolvePendingPlace();
      expect(scope.read(checkInFlowProvider('alice')).isResolvingPlace, isTrue);
      await expectLater(
        notifier.setPendingPlace(
          PendingPlaceDraft(
            name: 'Seconda',
            address: 'Via 2',
            latitude: 46,
            longitude: 10,
          ),
        ),
        throwsA(isA<CheckInFlowFailure>()),
      );
      places.pending!.complete(places.result('user_place_$id'));

      expect(await resolution, 'user_place_$id');
      final draft = scope.read(checkInFlowProvider('alice')).draft!;
      expect(draft.placeId, 'user_place_$id');
      expect(draft.pendingPlace, isNull);
    },
  );

  test(
    'existing place selection is blocked during an in-flight resolution',
    () async {
      final places = _PlaceRepository()..pending = Completer<Place>();
      final scope = container(
        drafts: _DraftRepository(),
        publication: _CheckInRepository(),
        storage: _StorageGateway(),
        places: places,
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);
      await notifier.setPendingPlace(
        PendingPlaceDraft(
          name: 'Nuova',
          address: 'Via 1',
          latitude: 45,
          longitude: 9,
        ),
      );

      final resolution = notifier.resolvePendingPlace();
      expect(scope.read(checkInFlowProvider('alice')).isResolvingPlace, isTrue);
      await expectLater(
        notifier.selectExistingPlace('existing-place'),
        throwsA(isA<CheckInFlowFailure>()),
      );
      places.pending!.complete(places.result('user_place_$id'));

      expect(await resolution, 'user_place_$id');
      final draft = scope.read(checkInFlowProvider('alice')).draft!;
      expect(draft.placeId, 'user_place_$id');
      expect(draft.pendingPlace, isNull);
    },
  );

  test('GPS failure does not create a place', () async {
    final location = _LocationGateway()
      ..error = const LocationFailure('no GPS');
    final places = _PlaceRepository();
    final scope = container(
      drafts: _DraftRepository(),
      publication: _CheckInRepository(),
      storage: _StorageGateway(),
      places: places,
      location: location,
    );
    addTearDown(scope.dispose);
    await initialized(scope);
    final notifier = scope.read(checkInFlowProvider('alice').notifier);
    await notifier.setPendingPlace(
      PendingPlaceDraft(name: 'Nuova', address: 'Via 1'),
    );

    await expectLater(
      notifier.resolvePendingPlace(),
      throwsA(isA<CheckInFlowFailure>()),
    );
    expect(places.calls, 0);
  });

  test(
    'route place preselection waits for catalog and never wins over restore',
    () async {
      final scope = container(
        drafts: _DraftRepository(),
        publication: _CheckInRepository(),
        storage: _StorageGateway(),
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);

      await notifier.applyPlacePreselection('place-1', const []);
      expect(scope.read(checkInFlowProvider('alice')).draft?.placeId, isNull);
      await notifier.applyPlacePreselection('place-1', const ['place-1']);
      expect(
        scope.read(checkInFlowProvider('alice')).draft?.placeId,
        'place-1',
      );
      await notifier.applyPlacePreselection('place-2', const ['place-2']);
      expect(
        scope.read(checkInFlowProvider('alice')).draft?.placeId,
        'place-1',
      );
    },
  );

  test(
    'friend preselection waits for accepted profiles and preserves restore',
    () async {
      final scope = container(
        drafts: _DraftRepository(),
        publication: _CheckInRepository(),
        storage: _StorageGateway(),
      );
      addTearDown(scope.dispose);
      await initialized(scope);
      final notifier = scope.read(checkInFlowProvider('alice').notifier);

      await notifier.applyFriendPreselection('bob', const []);
      expect(
        scope.read(checkInFlowProvider('alice')).draft?.taggedUserIds,
        isEmpty,
      );
      await notifier.applyFriendPreselection('bob', const ['bob']);
      expect(scope.read(checkInFlowProvider('alice')).draft?.taggedUserIds, [
        'bob',
      ]);
      await notifier.applyFriendPreselection('carol', const ['carol']);
      expect(scope.read(checkInFlowProvider('alice')).draft?.taggedUserIds, [
        'bob',
      ]);
    },
  );

  test(
    'missing restored staging object exposes recovery without public URL',
    () async {
      final drafts = _DraftRepository(initial: _completeDraft(id, now));
      final scope = container(
        drafts: drafts,
        publication: _CheckInRepository(),
        storage: _StorageGateway(readResult: null),
      );
      addTearDown(scope.dispose);

      final state = await initialized(scope);

      expect(state.photoMissing, isTrue);
      expect(state.photoBytes, isNull);
      expect(state.draft?.stagingObjectPath, 'staging/alice/$id.jpg');
    },
  );

  test('UID switch discards a late staging upload completion', () async {
    final drafts = _DraftRepository();
    final storage = _StorageGateway()..pendingPut = Completer<String>();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: storage,
    );
    addTearDown(scope.dispose);
    await initialized(scope);

    final operation = scope
        .read(checkInFlowProvider('alice').notifier)
        .selectPhoto(_onePixelPng(), 'gelato.png');
    while (storage.putPaths.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    scope.read(_activeUidProvider.notifier).setUid('bob');
    await Future<void>.delayed(Duration.zero);
    storage.pendingPut!.complete('staging/alice/$id.jpg');
    await operation;

    expect(drafts.saved.last.stagingObjectPath, isNull);
  });

  test('dispose discards a late staging upload completion', () async {
    final drafts = _DraftRepository();
    final storage = _StorageGateway()..pendingPut = Completer<String>();
    final scope = container(
      drafts: drafts,
      publication: _CheckInRepository(),
      storage: storage,
    );
    await initialized(scope);

    final operation = scope
        .read(checkInFlowProvider('alice').notifier)
        .selectPhoto(_onePixelPng(), 'gelato.png');
    while (storage.putPaths.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    scope.dispose();
    storage.pendingPut!.complete('staging/alice/$id.jpg');
    await operation;

    expect(drafts.saved.last.stagingObjectPath, isNull);
  });
}

CheckInDraft _completeDraft(String id, DateTime now) => CheckInDraft(
  id: id,
  currentStep: 4,
  localPhotoName: 'gelato.jpg',
  stagingObjectPath: 'staging/alice/$id.jpg',
  placeId: 'place-1',
  pendingPlace: null,
  gelatoTypeId: 'cono',
  flavorIds: const ['pistacchio'],
  rating: 5,
  reviewText: 'Buono',
  taggedUserIds: const ['bob'],
  updatedAt: now,
);

final class _DraftRepository implements CheckInDraftRepository {
  _DraftRepository({this.initial, this.events});

  CheckInDraft? initial;
  final List<String>? events;
  final List<CheckInDraft> saved = [];
  int clearCalls = 0;
  int saveCalls = 0;
  bool failNextSave = false;
  Object? clearError;

  @override
  Future<void> clear(String uid) async {
    clearCalls++;
    events?.add('draft.clear');
    if (clearError case final error?) throw error;
    initial = null;
  }

  @override
  Future<CheckInDraft?> load(String uid) async => initial;

  @override
  Future<void> save(String uid, CheckInDraft draft) async {
    saveCalls++;
    saved.add(draft);
    if (failNextSave) {
      failNextSave = false;
      throw StateError('draft save failed');
    }
    initial = draft;
  }
}

final class _PublicationStateRepository
    implements CheckInPublicationRepository {
  _PublicationStateRepository({CheckInPublicationMarker? initial, this.events})
    : marker = initial;

  CheckInPublicationMarker? marker;
  final List<String>? events;
  Object? saveError;
  Object? clearError;
  CheckInPublicationPhase? saveErrorForPhase;
  int clearCalls = 0;
  final List<CheckInPublicationMarker> saved = <CheckInPublicationMarker>[];

  @override
  Future<void> clear(String uid) async {
    clearCalls++;
    events?.add('outbox.clear');
    if (clearError case final error?) throw error;
    marker = null;
  }

  @override
  Future<CheckInPublicationMarker?> load(String uid) async => marker;

  @override
  Future<void> save(String uid, CheckInPublicationMarker next) async {
    if (saveError case final error?) throw error;
    if (next.phase == saveErrorForPhase) throw StateError('phase write failed');
    events?.add('outbox.save.${next.phase.name}');
    saved.add(next);
    marker = next;
  }
}

final class _CheckInRepository implements CheckInRepository {
  Object? error;
  Completer<PublishCheckInResult>? pending;
  int publishCalls = 0;

  @override
  Future<void> delete(String checkInId) async {}

  @override
  Future<PublishCheckInResult> publish(CheckInDraft draft) async {
    publishCalls++;
    if (error case final error?) throw error;
    if (pending case final pending?) return pending.future;
    return PublishCheckInResult(draft.id, PublishCheckInStatus.created);
  }
}

final class _StorageGateway implements StorageObjectGateway {
  _StorageGateway({this.readResult});

  final List<String> putPaths = [];
  Uint8List? readResult;
  bool failNextPut = false;
  Completer<String>? pendingPut;

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    putPaths.add(path);
    if (failNextPut) {
      failNextPut = false;
      throw StateError('network');
    }
    if (pendingPut case final pending?) return pending.future;
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async => readResult;
}

final class _ControlledStorageGateway implements StorageObjectGateway {
  final List<Uint8List> putBytes = <Uint8List>[];
  Completer<void>? firstPutGate;
  Completer<Uint8List?>? readGate;
  Uint8List? storedBytes;

  @override
  Future<String> put(
    String path,
    Uint8List bytes,
    SettableMetadata metadata,
  ) async {
    putBytes.add(Uint8List.fromList(bytes));
    final gate = firstPutGate;
    if (putBytes.length == 1 && gate != null) {
      await gate.future;
    }
    storedBytes = Uint8List.fromList(bytes);
    return path;
  }

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    if (readGate case final gate?) return gate.future;
    return null;
  }
}

final class _PlaceRepository implements PlaceRepository {
  int calls = 0;
  Completer<Place>? pending;

  Place result(String id) => Place(
    id: id,
    name: 'Nuova',
    address: 'Via 1',
    location: const GeoPoint(45, 9),
    geohash: 'u0n',
    createdAt: DateTime.utc(2026, 7, 15),
    addedByUid: 'alice',
  );

  @override
  Future<Place> createPlace({
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    calls++;
    if (pending case final pending?) return pending.future;
    return result('new-place');
  }

  @override
  Future<Place> createOrReadPlace({
    required String placeId,
    required String name,
    required String address,
    required GeoPoint location,
  }) async {
    calls++;
    if (pending case final pending?) return pending.future;
    return result(placeId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LocationGateway implements LocationGateway {
  int calls = 0;
  Object? error;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    calls++;
    if (error case final error?) throw error;
    return const DeviceLocation(latitude: 45.46, longitude: 9.19);
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
}

Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Uint8List _solidPng({required int red, required int green, required int blue}) {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(red, green, blue));
  return Uint8List.fromList(img.encodePng(image));
}
