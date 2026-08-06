import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../firebase/firebase_providers.dart';
import '../models/check_in_draft.dart';
import '../repositories/check_in_draft_repository.dart';
import '../repositories/check_in_label_repository.dart';
import '../repositories/check_in_publication_repository.dart';
import '../repositories/check_in_repository.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';
import 'check_in_providers.dart';
import 'location_provider.dart';
import 'place_providers.dart';

export 'check_in_providers.dart' show checkInRepositoryProvider;

typedef CheckInClock = DateTime Function();
typedef CheckInIdGenerator = String Function();

final checkInClockProvider = Provider<CheckInClock>((ref) => DateTime.now);

final checkInIdGeneratorProvider = Provider<CheckInIdGenerator>(
  (ref) => const Uuid().v4,
);

final checkInDraftRepositoryProvider = Provider<CheckInDraftRepository>((ref) {
  final SharedPreferences preferences = ref.watch(sharedPreferencesProvider);
  return PersistentCheckInDraftRepository(
    SharedPreferencesDraftPreferences(preferences),
  );
});

final checkInLabelRepositoryProvider = Provider<CheckInLabelRepository>(
  (ref) => InMemoryCheckInLabelRepository(),
);

final checkInPublicationRepositoryProvider =
    Provider<CheckInPublicationRepository>((ref) {
      final SharedPreferences preferences = ref.watch(
        sharedPreferencesProvider,
      );
      return PersistentCheckInPublicationRepository(
        SharedPreferencesDraftPreferences(preferences),
      );
    });

enum CheckInFlowFailureKind {
  initialization,
  persistence,
  photo,
  place,
  publication,
}

final class CheckInFlowFailure implements Exception {
  const CheckInFlowFailure({
    required this.kind,
    required this.message,
    required this.cause,
  });

  final CheckInFlowFailureKind kind;
  final String message;
  final Object cause;

  @override
  String toString() => message;
}

const Object _flowUnset = Object();

final class CheckInFlowState {
  const CheckInFlowState({
    this.draft,
    this.photoBytes,
    this.isInitializing = true,
    this.isSaving = false,
    this.isUploading = false,
    this.isPublishing = false,
    this.isResolvingPlace = false,
    this.isDirty = false,
    this.photoMissing = false,
    this.published = false,
    this.publishedPendingClear = false,
    this.publicationCallingPendingRetry = false,
    this.publicationFailedPendingClear = false,
    this.publicationDraftId,
    this.failure,
  });

  final CheckInDraft? draft;
  final Uint8List? photoBytes;
  final bool isInitializing;
  final bool isSaving;
  final bool isUploading;
  final bool isPublishing;
  final bool isResolvingPlace;
  final bool isDirty;
  final bool photoMissing;
  final bool published;
  final bool publishedPendingClear;
  final bool publicationCallingPendingRetry;
  final bool publicationFailedPendingClear;
  final String? publicationDraftId;
  final CheckInFlowFailure? failure;

  bool get isPublicationLocked =>
      isPublishing ||
      publicationCallingPendingRetry ||
      publicationFailedPendingClear ||
      publishedPendingClear ||
      published;

  bool get isEditorLocked => isPublicationLocked || isResolvingPlace;

  CheckInFlowState copyWith({
    Object? draft = _flowUnset,
    Object? photoBytes = _flowUnset,
    bool? isInitializing,
    bool? isSaving,
    bool? isUploading,
    bool? isPublishing,
    bool? isResolvingPlace,
    bool? isDirty,
    bool? photoMissing,
    bool? published,
    bool? publishedPendingClear,
    bool? publicationCallingPendingRetry,
    bool? publicationFailedPendingClear,
    Object? publicationDraftId = _flowUnset,
    Object? failure = _flowUnset,
  }) => CheckInFlowState(
    draft: identical(draft, _flowUnset) ? this.draft : draft as CheckInDraft?,
    photoBytes: identical(photoBytes, _flowUnset)
        ? this.photoBytes
        : photoBytes as Uint8List?,
    isInitializing: isInitializing ?? this.isInitializing,
    isSaving: isSaving ?? this.isSaving,
    isUploading: isUploading ?? this.isUploading,
    isPublishing: isPublishing ?? this.isPublishing,
    isResolvingPlace: isResolvingPlace ?? this.isResolvingPlace,
    isDirty: isDirty ?? this.isDirty,
    photoMissing: photoMissing ?? this.photoMissing,
    published: published ?? this.published,
    publishedPendingClear: publishedPendingClear ?? this.publishedPendingClear,
    publicationCallingPendingRetry:
        publicationCallingPendingRetry ?? this.publicationCallingPendingRetry,
    publicationFailedPendingClear:
        publicationFailedPendingClear ?? this.publicationFailedPendingClear,
    publicationDraftId: identical(publicationDraftId, _flowUnset)
        ? this.publicationDraftId
        : publicationDraftId as String?,
    failure: identical(failure, _flowUnset)
        ? this.failure
        : failure as CheckInFlowFailure?,
  );
}

final checkInFlowProvider = NotifierProvider.autoDispose
    .family<CheckInFlowController, CheckInFlowState, String>(
      CheckInFlowController.new,
    );

final class CheckInFlowController extends Notifier<CheckInFlowState> {
  CheckInFlowController(this.uid);

  final String uid;
  bool _active = true;
  int _generation = 0;
  int _saveVersion = 0;
  int _photoVersion = 0;
  int _placeVersion = 0;
  Future<void>? _latestSave;
  Future<void>? _photoUploadTail;
  Future<String?>? _placeResolution;
  Future<PublishCheckInResult>? _publishOperation;
  PublishCheckInResult? _publishedResult;
  String? _publicationDraftId;
  CheckInFlowFailure? _publicationFailure;

  @override
  CheckInFlowState build() {
    _active = true;
    final generation = ++_generation;
    ref.onDispose(() {
      _active = false;
      _generation++;
    });
    Future<void>.microtask(() => _initialize(generation));
    return const CheckInFlowState();
  }

  bool _isCurrent(int generation) =>
      _active &&
      _generation == generation &&
      ref.mounted &&
      ref.read(currentUidProvider) == uid;

  Future<void> _initialize(int generation) async {
    try {
      final draftRepository = ref.read(checkInDraftRepositoryProvider);
      final publicationRepository = ref.read(
        checkInPublicationRepositoryProvider,
      );
      final marker = await publicationRepository.load(uid);
      if (!_isCurrent(generation)) return;
      var draft = await draftRepository.load(uid);
      if (!_isCurrent(generation)) return;

      if (marker != null) {
        _publicationDraftId = marker.draftId;
        if (marker.phase == CheckInPublicationPhase.calling) {
          final isOrphan = draft == null || draft.id != marker.draftId;
          state = state.copyWith(
            draft: draft,
            isInitializing: false,
            isDirty: false,
            publicationCallingPendingRetry: true,
            publicationDraftId: marker.draftId,
            failure: isOrphan
                ? CheckInFlowFailure(
                    kind: CheckInFlowFailureKind.initialization,
                    message:
                        'Stato di pubblicazione incompleto: la bozza locale non corrisponde.',
                    cause: StateError('orphan calling publication marker'),
                  )
                : null,
          );
          return;
        }

        if (marker.phase == CheckInPublicationPhase.failed) {
          final failure = _flowFailureFor(marker.failure!);
          _publicationFailure = failure;
          state = state.copyWith(
            draft: draft,
            isInitializing: false,
            isDirty: false,
            publicationFailedPendingClear: true,
            publicationDraftId: marker.draftId,
            failure: failure,
          );
          return;
        }

        final result = marker.result!;
        final isMismatched = draft != null && draft.id != marker.draftId;
        _publishedResult = result;
        state = state.copyWith(
          draft: draft,
          isInitializing: false,
          isDirty: false,
          publishedPendingClear: true,
          publicationDraftId: marker.draftId,
          failure: isMismatched
              ? CheckInFlowFailure(
                  kind: CheckInFlowFailureKind.initialization,
                  message:
                      'Check-in pubblicato, ma la bozza locale non corrisponde.',
                  cause: StateError('mismatched published publication marker'),
                )
              : null,
        );
        return;
      }

      if (draft == null) {
        draft = CheckInDraft.create(
          idGenerator: ref.read(checkInIdGeneratorProvider),
          now: ref.read(checkInClockProvider),
        );
        await draftRepository.save(uid, draft);
        if (!_isCurrent(generation)) return;
      }
      final path = draft.stagingObjectPath;
      state = state.copyWith(
        draft: draft,
        isInitializing: path != null,
        isDirty: false,
        failure: null,
      );
      if (path == null) return;

      final photoVersion = _photoVersion;
      try {
        final bytes = await ref
            .read(storageServiceProvider)
            .readAuthenticatedObject(path);
        if (!_isPhotoCurrent(generation, photoVersion)) return;
        state = state.copyWith(
          photoBytes: bytes,
          photoMissing: bytes == null,
          isInitializing: false,
        );
      } catch (error) {
        if (!_isPhotoCurrent(generation, photoVersion)) return;
        state = state.copyWith(
          photoBytes: null,
          photoMissing: true,
          isInitializing: false,
          failure: _wrap(
            CheckInFlowFailureKind.photo,
            'Impossibile verificare la foto privata.',
            error,
          ),
        );
      }
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        isInitializing: false,
        failure: CheckInFlowFailure(
          kind: CheckInFlowFailureKind.initialization,
          message: 'Impossibile ripristinare la bozza del check-in.',
          cause: error,
        ),
      );
    }
  }

  Future<void> selectPhoto(Uint8List bytes, String localPhotoName) async {
    final draft = _requireMutableDraft();
    final generation = _generation;
    final photoVersion = ++_photoVersion;
    final updatedDraft = draft.copyWith(
      localPhotoName: localPhotoName,
      stagingObjectPath: null,
      updatedAt: _now(),
    );
    state = state.copyWith(
      photoBytes: Uint8List.fromList(bytes),
      photoMissing: false,
      isUploading: true,
      failure: null,
    );
    try {
      await _persist(updatedDraft);
    } catch (_) {
      if (_isPhotoCurrent(generation, photoVersion)) {
        state = state.copyWith(isUploading: false);
      }
      rethrow;
    }
    if (!_isPhotoCurrent(generation, photoVersion)) return;
    await _queuePhotoUpload(
      generation: generation,
      photoVersion: photoVersion,
      bytes: Uint8List.fromList(bytes),
      checkInId: draft.id,
    );
  }

  Future<void> retryPhotoUpload() async {
    final draft = _requireMutableDraft();
    final generation = _generation;
    final photoVersion = ++_photoVersion;
    final bytes = state.photoBytes;
    if (bytes == null) {
      final failure = CheckInFlowFailure(
        kind: CheckInFlowFailureKind.photo,
        message: 'Riseleziona la foto per riprendere il caricamento.',
        cause: const StorageImageFailure(),
      );
      state = state.copyWith(failure: failure, photoMissing: true);
      return;
    }
    state = state.copyWith(isUploading: true, failure: null);
    await _queuePhotoUpload(
      generation: generation,
      photoVersion: photoVersion,
      bytes: Uint8List.fromList(bytes),
      checkInId: draft.id,
    );
  }

  Future<void> retryRestoredPhotoRead() async {
    final path = _requireMutableDraft().stagingObjectPath;
    if (path == null) return;
    final generation = _generation;
    final photoVersion = ++_photoVersion;
    try {
      final bytes = await ref
          .read(storageServiceProvider)
          .readAuthenticatedObject(path);
      if (!_isPhotoCurrent(generation, photoVersion)) return;
      state = state.copyWith(
        photoBytes: bytes,
        photoMissing: bytes == null,
        failure: null,
      );
    } catch (error) {
      final failure = _wrap(
        CheckInFlowFailureKind.photo,
        'Impossibile verificare la foto privata.',
        error,
      );
      if (!_isPhotoCurrent(generation, photoVersion)) return;
      state = state.copyWith(failure: failure);
      throw failure;
    }
  }

  Future<void> removePhoto() async {
    final draft = _requireMutableDraft();
    ++_photoVersion;
    state = state.copyWith(
      photoBytes: null,
      photoMissing: false,
      isInitializing: false,
      isUploading: false,
      failure: null,
    );
    await _persist(
      draft.copyWith(
        localPhotoName: null,
        stagingObjectPath: null,
        updatedAt: _now(),
      ),
    );
  }

  Future<bool> _queuePhotoUpload({
    required int generation,
    required int photoVersion,
    required Uint8List bytes,
    required String checkInId,
  }) {
    final previous = _photoUploadTail;
    final operation = () async {
      if (previous != null) await previous;
      if (!_isPhotoCurrent(generation, photoVersion)) return false;
      return _performPhotoUpload(
        generation: generation,
        photoVersion: photoVersion,
        bytes: bytes,
        checkInId: checkInId,
      );
    }();
    _photoUploadTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<bool> _performPhotoUpload({
    required int generation,
    required int photoVersion,
    required Uint8List bytes,
    required String checkInId,
  }) async {
    try {
      final path = await ref
          .read(storageServiceProvider)
          .uploadStagingPhoto(bytes: bytes, uid: uid, checkInId: checkInId);
      if (!_isPhotoCurrent(generation, photoVersion)) return false;
      await _persist(
        _requireDraft().copyWith(stagingObjectPath: path, updatedAt: _now()),
      );
      if (_isPhotoCurrent(generation, photoVersion)) {
        state = state.copyWith(isUploading: false, photoMissing: false);
      }
      return true;
    } catch (error) {
      final failure = _wrap(
        CheckInFlowFailureKind.photo,
        'Caricamento della foto interrotto. Riprova.',
        error,
      );
      if (_isPhotoCurrent(generation, photoVersion)) {
        state = state.copyWith(isUploading: false, failure: failure);
      }
      return false;
    }
  }

  bool _isPhotoCurrent(int generation, int photoVersion) =>
      _isCurrent(generation) &&
      !state.isEditorLocked &&
      _photoVersion == photoVersion;

  Future<void> setStep(int step) async {
    final draft = _requireMutableDraft();
    await _persist(draft.copyWith(currentStep: step, updatedAt: _now()));
  }

  Future<void> selectExistingPlace(String placeId) async {
    final draft = _requireMutableDraft();
    _invalidatePlaceResolution();
    await _persist(
      draft.copyWith(placeId: placeId, pendingPlace: null, updatedAt: _now()),
    );
  }

  Future<void> setPendingPlace(PendingPlaceDraft pendingPlace) async {
    final draft = _requireMutableDraft();
    _invalidatePlaceResolution();
    await _persist(
      draft.copyWith(
        placeId: null,
        pendingPlace: pendingPlace,
        updatedAt: _now(),
      ),
    );
  }

  Future<void> applyPlacePreselection(
    String placeId,
    Iterable<String> availablePlaceIds,
  ) async {
    final draft = _requireMutableDraft();
    if (draft.placeId != null || draft.pendingPlace != null) return;
    if (!availablePlaceIds.contains(placeId)) return;
    await selectExistingPlace(placeId);
  }

  Future<void> applyFriendPreselection(
    String friendUid,
    Iterable<String> acceptedFriendUids,
  ) async {
    final draft = _requireMutableDraft();
    if (draft.taggedUserIds.isNotEmpty) return;
    if (!acceptedFriendUids.contains(friendUid)) return;
    await setTaggedUsers(<String>[friendUid]);
  }

  Future<String?> resolvePendingPlace() {
    final current = _placeResolution;
    if (current != null) return current;
    if (state.isPublicationLocked) {
      return Future<String?>.error(_lockedFailure());
    }
    _requireDraft();
    final generation = _generation;
    final placeVersion = _placeVersion;
    state = state.copyWith(isResolvingPlace: true, failure: null);
    late final Future<String?> operation;
    operation = _resolvePendingPlace(generation, placeVersion);
    _placeResolution = operation;
    operation.then<void>(
      (_) {
        _completePlaceResolution(operation, generation);
      },
      onError: (_, _) {
        _completePlaceResolution(operation, generation);
      },
    );
    return operation;
  }

  void _completePlaceResolution(Future<String?> operation, int generation) {
    if (!identical(_placeResolution, operation)) return;
    _placeResolution = null;
    if (_isCurrent(generation)) {
      state = state.copyWith(isResolvingPlace: false);
    }
  }

  Future<String?> _resolvePendingPlace(int generation, int placeVersion) async {
    var draft = _requireDraft();
    if (draft.placeId != null) return draft.placeId;
    var pending = draft.pendingPlace;
    if (pending == null) return null;
    try {
      if (pending.name.isEmpty || pending.address.isEmpty) {
        throw const FormatException('pending_place: name and address required');
      }
      if (!pending.hasCoordinates) {
        final location = await ref
            .read(deviceLocationServiceProvider)
            .currentLocation();
        if (!_isPlaceCurrent(generation, placeVersion)) return null;
        pending = PendingPlaceDraft(
          name: pending.name,
          address: pending.address,
          latitude: location.latitude,
          longitude: location.longitude,
        );
        await _persist(
          draft.copyWith(pendingPlace: pending, updatedAt: _now()),
        );
        if (!_isPlaceCurrent(generation, placeVersion)) return null;
        draft = _requireDraft();
      }
      final place = await ref
          .read(placeRepositoryProvider)
          .createOrReadPlace(
            placeId: 'user_place_${draft.id}',
            name: pending.name,
            address: pending.address,
            location: GeoPoint(pending.latitude!, pending.longitude!),
          );
      if (!_isPlaceCurrent(generation, placeVersion)) return null;
      await _persist(
        draft.copyWith(
          placeId: place.id,
          pendingPlace: null,
          updatedAt: _now(),
        ),
      );
      if (!_isPlaceCurrent(generation, placeVersion)) return null;
      return place.id;
    } catch (error) {
      if (!_isPlaceCurrent(generation, placeVersion)) return null;
      final failure = _wrap(
        CheckInFlowFailureKind.place,
        'Impossibile creare la gelateria senza una posizione valida.',
        error,
      );
      state = state.copyWith(failure: failure);
      throw failure;
    }
  }

  void _invalidatePlaceResolution() {
    _placeVersion++;
    _placeResolution = null;
  }

  bool _isPlaceCurrent(int generation, int placeVersion) =>
      _isCurrent(generation) &&
      !state.isPublicationLocked &&
      _placeVersion == placeVersion;

  Future<void> setGelato({
    required String gelatoTypeId,
    required List<String> flavorIds,
  }) async {
    final draft = _requireMutableDraft();
    await _persist(
      draft.copyWith(
        gelatoTypeId: gelatoTypeId,
        flavorIds: flavorIds,
        updatedAt: _now(),
      ),
    );
  }

  Future<void> setGelatoType(String? gelatoTypeId) async {
    final draft = _requireMutableDraft();
    await _persist(
      draft.copyWith(gelatoTypeId: gelatoTypeId, updatedAt: _now()),
    );
  }

  Future<void> setFlavorIds(List<String> flavorIds) async {
    final draft = _requireMutableDraft();
    await _persist(draft.copyWith(flavorIds: flavorIds, updatedAt: _now()));
  }

  Future<void> setRating(int? rating) async {
    final draft = _requireMutableDraft();
    await _persist(draft.copyWith(rating: rating, updatedAt: _now()));
  }

  Future<void> setReviewText(String reviewText) async {
    final draft = _requireMutableDraft();
    await _persist(draft.copyWith(reviewText: reviewText, updatedAt: _now()));
  }

  /// Null restores the default, where the server stamps publication time.
  Future<void> setConsumedAt(DateTime? consumedAt) async {
    final draft = _requireMutableDraft();
    await _persist(draft.copyWith(consumedAt: consumedAt, updatedAt: _now()));
  }

  Future<void> setExperience({
    required int rating,
    required String reviewText,
  }) async {
    final draft = _requireMutableDraft();
    await _persist(
      draft.copyWith(rating: rating, reviewText: reviewText, updatedAt: _now()),
    );
  }

  Future<void> setTaggedUsers(List<String> taggedUserIds) async {
    final draft = _requireMutableDraft();
    await _persist(
      draft.copyWith(taggedUserIds: taggedUserIds, updatedAt: _now()),
    );
  }

  Future<void> retryDraftSave() => _persist(_requireMutableDraft());

  Future<PublishCheckInResult> publish() {
    final current = _publishOperation;
    if (current != null) return current;
    final publishedResult = _publishedResult;
    if ((state.publishedPendingClear || state.published) &&
        publishedResult != null) {
      if (state.published) return Future.value(publishedResult);
      return _trackPublishOperation(_clearPublishedDraft(publishedResult));
    }
    if (state.publicationFailedPendingClear) {
      return _trackPublishOperation(_clearFailedPublication());
    }
    if (state.publicationCallingPendingRetry) {
      return _trackPublishOperation(_retryCallingPublication());
    }
    return _trackPublishOperation(_beginPublication());
  }

  Future<PublishCheckInResult> _trackPublishOperation(
    Future<PublishCheckInResult> operation,
  ) {
    _publishOperation = operation;
    operation.then<void>(
      (_) {
        if (identical(_publishOperation, operation)) _publishOperation = null;
      },
      onError: (_, _) {
        if (identical(_publishOperation, operation)) _publishOperation = null;
      },
    );
    return operation;
  }

  Future<PublishCheckInResult> _beginPublication() async {
    final generation = _generation;
    state = state.copyWith(isPublishing: true, failure: null);
    try {
      final pendingSave = _latestSave;
      if (pendingSave != null) await pendingSave;
      final draft = _requireDraft();
      await ref
          .read(checkInPublicationRepositoryProvider)
          .save(uid, CheckInPublicationMarker.calling(draft.id));
      if (!_isCurrent(generation)) {
        throw StateError('check-in flow disposed after publication marker');
      }
      state = state.copyWith(
        publicationCallingPendingRetry: true,
        publicationDraftId: draft.id,
        isPublishing: true,
      );
      _publicationDraftId = draft.id;
      return _callAndPersistPublished(draft, generation);
    } catch (error) {
      if (error is CheckInFlowFailure) {
        if (_isCurrent(generation)) {
          state = state.copyWith(isPublishing: false, failure: error);
        }
        rethrow;
      }
      final failure = _wrap(
        CheckInFlowFailureKind.persistence,
        'Impossibile preparare la pubblicazione in modo sicuro.',
        error,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publicationCallingPendingRetry: false,
          failure: failure,
        );
      }
      throw failure;
    }
  }

  Future<PublishCheckInResult> _retryCallingPublication() async {
    final generation = _generation;
    final draft = state.draft;
    if (draft == null || draft.id != _publicationDraftId) {
      final failure = CheckInFlowFailure(
        kind: CheckInFlowFailureKind.initialization,
        message:
            'Stato di pubblicazione incompleto: la bozza locale non è disponibile.',
        cause: StateError('orphan calling publication marker'),
      );
      state = state.copyWith(failure: failure);
      throw failure;
    }
    state = state.copyWith(isPublishing: true, failure: null);
    return _callAndPersistPublished(draft, generation);
  }

  Future<PublishCheckInResult> _callAndPersistPublished(
    CheckInDraft draft,
    int generation,
  ) async {
    final publication = ref.read(checkInRepositoryProvider);
    final outbox = ref.read(checkInPublicationRepositoryProvider);
    PublishCheckInResult result;
    try {
      result = await publication.publish(draft);
    } catch (error) {
      final definitiveReason = _definitiveReason(error);
      if (definitiveReason != null) {
        return _transitionToFailed(
          draft,
          generation,
          error as CheckInFailure,
          definitiveReason,
          outbox,
        );
      }
      final failure = _wrap(
        CheckInFlowFailureKind.publication,
        error is CheckInFailure
            ? error.message
            : 'Pubblicazione interrotta. Riprova.',
        error,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publicationCallingPendingRetry: true,
          failure: failure,
        );
      }
      throw failure;
    }

    if (!_isCurrent(generation)) return result;
    try {
      await outbox.save(
        uid,
        CheckInPublicationMarker.published(draft.id, result),
      );
    } catch (error) {
      final failure = _wrap(
        CheckInFlowFailureKind.persistence,
        'Check-in inviato, ma la conferma locale non è stata salvata.',
        error,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publicationCallingPendingRetry: true,
          failure: failure,
        );
      }
      throw failure;
    }
    if (!_isCurrent(generation)) return result;

    _publishedResult = result;
    state = state.copyWith(
      isPublishing: true,
      publicationCallingPendingRetry: false,
      publishedPendingClear: true,
      failure: null,
    );
    return _clearPublishedDraft(result);
  }

  Future<PublishCheckInResult> _transitionToFailed(
    CheckInDraft draft,
    int generation,
    CheckInFailure error,
    CheckInPublicationFailureReason reason,
    CheckInPublicationRepository outbox,
  ) async {
    final failure = _wrap(
      CheckInFlowFailureKind.publication,
      error.message,
      error,
    );
    if (!_isCurrent(generation)) throw failure;
    try {
      await outbox.save(uid, CheckInPublicationMarker.failed(draft.id, reason));
    } catch (markerError) {
      final persistenceFailure = _wrap(
        CheckInFlowFailureKind.persistence,
        'Pubblicazione rifiutata, ma lo sblocco locale non è stato salvato.',
        markerError,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publicationCallingPendingRetry: true,
          publicationFailedPendingClear: false,
          failure: persistenceFailure,
        );
      }
      throw persistenceFailure;
    }
    if (!_isCurrent(generation)) throw failure;

    _publicationFailure = failure;
    state = state.copyWith(
      isPublishing: true,
      publicationCallingPendingRetry: false,
      publicationFailedPendingClear: true,
      failure: failure,
    );
    return _clearFailedPublication();
  }

  Future<PublishCheckInResult> _clearFailedPublication() async {
    final generation = _generation;
    final failure =
        _publicationFailure ??
        const CheckInFlowFailure(
          kind: CheckInFlowFailureKind.publication,
          message: 'La pubblicazione è stata rifiutata. Correggi il check-in.',
          cause: CheckInPreconditionFailure(),
        );
    state = state.copyWith(
      isPublishing: true,
      publicationCallingPendingRetry: false,
      publicationFailedPendingClear: true,
      failure: failure,
    );
    try {
      await ref.read(checkInPublicationRepositoryProvider).clear(uid);
    } catch (error) {
      final persistenceFailure = _wrap(
        CheckInFlowFailureKind.persistence,
        'Pubblicazione rifiutata, ma lo stato locale non è stato ripulito.',
        error,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publicationFailedPendingClear: true,
          failure: persistenceFailure,
        );
      }
      throw persistenceFailure;
    }
    if (_isCurrent(generation)) {
      state = state.copyWith(
        isPublishing: false,
        publicationFailedPendingClear: false,
        publicationDraftId: null,
        failure: failure,
      );
      _publicationDraftId = null;
    }
    throw failure;
  }

  Future<PublishCheckInResult> _clearPublishedDraft(
    PublishCheckInResult result,
  ) async {
    final generation = _generation;
    final draftRepository = ref.read(checkInDraftRepositoryProvider);
    final publicationRepository = ref.read(
      checkInPublicationRepositoryProvider,
    );
    state = state.copyWith(
      isPublishing: true,
      publicationCallingPendingRetry: false,
      publishedPendingClear: true,
      failure: null,
    );
    final draft = state.draft;
    if (draft != null && draft.id != result.checkInId) {
      final failure = CheckInFlowFailure(
        kind: CheckInFlowFailureKind.initialization,
        message: 'Check-in pubblicato, ma la bozza locale non corrisponde.',
        cause: StateError('published marker does not match local draft'),
      );
      state = state.copyWith(isPublishing: false, failure: failure);
      throw failure;
    }
    if (draft != null) {
      try {
        await draftRepository.clear(uid);
      } catch (error) {
        final failure = _wrap(
          CheckInFlowFailureKind.persistence,
          'Check-in pubblicato, ma la bozza locale non è stata rimossa.',
          error,
        );
        if (_isCurrent(generation)) {
          state = state.copyWith(
            isPublishing: false,
            publishedPendingClear: true,
            failure: failure,
          );
        }
        throw failure;
      }
      if (!_isCurrent(generation)) return result;
      state = state.copyWith(
        draft: null,
        photoBytes: null,
        isDirty: false,
        photoMissing: false,
      );
    }

    try {
      await publicationRepository.clear(uid);
    } catch (error) {
      final failure = _wrap(
        CheckInFlowFailureKind.persistence,
        'Check-in pubblicato, ma lo stato locale non è stato ripulito.',
        error,
      );
      if (_isCurrent(generation)) {
        state = state.copyWith(
          isPublishing: false,
          publishedPendingClear: true,
          failure: failure,
        );
      }
      throw failure;
    }
    if (_isCurrent(generation)) {
      state = state.copyWith(
        isPublishing: false,
        published: true,
        publishedPendingClear: false,
        failure: null,
      );
      _publicationDraftId = null;
    }
    return result;
  }

  Future<void> _persist(CheckInDraft draft) {
    final generation = _generation;
    final version = ++_saveVersion;
    state = state.copyWith(
      draft: draft,
      isSaving: true,
      isDirty: true,
      failure: null,
    );
    final operation = () async {
      try {
        await ref.read(checkInDraftRepositoryProvider).save(uid, draft);
        if (_isCurrent(generation) && version == _saveVersion) {
          state = state.copyWith(isSaving: false, isDirty: false);
        }
      } catch (error) {
        final failure = _wrap(
          CheckInFlowFailureKind.persistence,
          'Impossibile salvare l’ultima modifica della bozza.',
          error,
        );
        if (_isCurrent(generation) && version == _saveVersion) {
          state = state.copyWith(
            isSaving: false,
            isDirty: true,
            failure: failure,
          );
        }
        throw failure;
      }
    }();
    _latestSave = operation;
    return operation;
  }

  CheckInDraft _requireDraft() {
    final draft = state.draft;
    if (draft == null) {
      throw StateError('Check-in draft is unavailable.');
    }
    return draft;
  }

  CheckInDraft _requireMutableDraft() {
    if (state.isEditorLocked) throw _lockedFailure();
    return _requireDraft();
  }

  CheckInFlowFailure _lockedFailure() => state.isResolvingPlace
      ? CheckInFlowFailure(
          kind: CheckInFlowFailureKind.place,
          message: 'Attendi il completamento della gelateria.',
          cause: StateError('place resolution in progress'),
        )
      : CheckInFlowFailure(
          kind: CheckInFlowFailureKind.persistence,
          message: 'Il check-in è già pubblicato: completa la pulizia locale.',
          cause: StateError('published check-in is immutable'),
        );

  DateTime _now() => ref.read(checkInClockProvider)();

  CheckInPublicationFailureReason? _definitiveReason(
    Object error,
  ) => switch (error) {
    CheckInAuthenticationFailure() =>
      CheckInPublicationFailureReason.authentication,
    CheckInPermissionFailure() => CheckInPublicationFailureReason.permission,
    CheckInValidationFailure() => CheckInPublicationFailureReason.validation,
    CheckInMediaMissingFailure() =>
      CheckInPublicationFailureReason.mediaMissing,
    CheckInPreconditionFailure() =>
      CheckInPublicationFailureReason.precondition,
    _ => null,
  };

  CheckInFlowFailure _flowFailureFor(CheckInPublicationFailureReason reason) {
    final failure = switch (reason) {
      CheckInPublicationFailureReason.authentication =>
        const CheckInAuthenticationFailure(),
      CheckInPublicationFailureReason.permission =>
        const CheckInPermissionFailure(),
      CheckInPublicationFailureReason.validation =>
        const CheckInValidationFailure('I dati del check-in non sono validi.'),
      CheckInPublicationFailureReason.mediaMissing =>
        const CheckInMediaMissingFailure(),
      CheckInPublicationFailureReason.precondition =>
        const CheckInPreconditionFailure(),
    };
    return CheckInFlowFailure(
      kind: CheckInFlowFailureKind.publication,
      message: failure.message,
      cause: failure,
    );
  }

  CheckInFlowFailure _wrap(
    CheckInFlowFailureKind kind,
    String message,
    Object error,
  ) => error is CheckInFlowFailure
      ? error
      : CheckInFlowFailure(kind: kind, message: message, cause: error);
}
