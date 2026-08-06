import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/check_in_draft.dart';
import '../../models/flavor.dart';
import '../../models/gelato_type.dart';
import '../../models/place.dart';
import '../../models/public_profile.dart';
import '../../e2e/emulator_photo_fixture.dart';
import '../../providers/auth_provider.dart';
import '../../providers/check_in_flow_provider.dart';
import '../../providers/flavors_provider.dart';
import '../../providers/friendship_providers.dart';
import '../../providers/gelato_types_provider.dart';
import '../../providers/place_providers.dart';
import '../../repositories/check_in_label_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gelato_background.dart';
import 'check_in_navigation.dart';
import 'check_in_progress.dart';
import 'check_in_step_rail.dart';
import 'experience_step.dart';
import 'gelato_step.dart';
import 'photo_step.dart';
import 'place_step.dart';
import 'share_step.dart';
import '../../constants/app_strings.dart';

final class CheckInFlow extends ConsumerStatefulWidget {
  const CheckInFlow({
    required this.uid,
    required this.onCompleted,
    required this.onExit,
    this.placeId,
    this.prefillFriendId,
    super.key,
  });

  final String uid;
  final String? placeId;
  final String? prefillFriendId;
  final VoidCallback onCompleted;
  final VoidCallback onExit;

  @override
  ConsumerState<CheckInFlow> createState() => _CheckInFlowState();
}

typedef _CheckInLifecycleSnapshot = ({
  String uid,
  String draftId,
  int generation,
  CheckInFlowController controller,
});

final class _CheckInFlowState extends ConsumerState<CheckInFlow> {
  static const _missingPlaceFields =
      AppStrings.checkInMissingPlace;
  static const _missingType = AppStrings.checkInMissingType;
  static const _invalidFlavors = AppStrings.checkInInvalidFlavors;
  static const _missingRating = AppStrings.checkInInvalidRating;
  static const _invalidPlaceLocation =
      AppStrings.checkInPlaceNoLocation;
  static const _photoUploadFailure =
      AppStrings.checkInPhotoInterrupted;
  static const _flavorCreationFailure = AppStrings.checkInFlavorCreateFailed;
  static const _labelLoadFailureMessage =
      AppStrings.checkInLabelsRestoreFailed;
  static const _unresolvedLabelsMessage =
      AppStrings.checkInLabelsUnavailable;
  static const _friendsVerificationMessage =
      AppStrings.checkInAwaitFriendsVerify;

  final _placeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _reviewController = TextEditingController();
  final _placeNames = <String, String>{};
  final _typeNames = <String, String>{};
  final _flavorNames = <String, String>{};
  final _friendNames = <String, String>{};

  String? _hydratedDraftId;
  int _labelGeneration = 0;
  bool _labelsLoaded = false;
  bool _isLoadingLabels = false;
  bool _labelLoadFailed = false;
  bool _labelSavePending = false;
  bool _labelSaveScheduled = false;
  int _labelScheduleVersion = 0;
  bool _isSavingLabels = false;
  bool _labelSaveFailed = false;
  int _labelSaveVersion = 0;
  Future<void>? _latestLabelSave;
  bool _isNewPlace = false;
  bool _showMap = false;
  bool _didComplete = false;
  bool _placePreselectionScheduled = false;
  bool _friendPreselectionScheduled = false;
  String? _friendReconciliationSignature;
  bool _friendsVerificationPending = false;
  String? _stepError;

  @override
  void didUpdateWidget(covariant CheckInFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _cancelLifecycle();
    }
    if (oldWidget.placeId != widget.placeId) {
      _placePreselectionScheduled = false;
    }
    if (oldWidget.prefillFriendId != widget.prefillFriendId) {
      _friendPreselectionScheduled = false;
      _friendReconciliationSignature = null;
    }
  }

  void _cancelLifecycle() {
    _labelGeneration++;
    _labelScheduleVersion++;
    _hydratedDraftId = null;
    _resetDraftTransients();
  }

  void _resetDraftTransients() {
    _placePreselectionScheduled = false;
    _friendPreselectionScheduled = false;
    _friendReconciliationSignature = null;
    _friendsVerificationPending = false;
    _showMap = false;
    _stepError = null;
    _didComplete = false;
  }

  @override
  void dispose() {
    _labelGeneration++;
    _labelScheduleVersion++;
    _placeNameController.dispose();
    _addressController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _hydrate(CheckInDraft draft) {
    if (_hydratedDraftId == draft.id) return;
    _resetDraftTransients();
    _hydratedDraftId = draft.id;
    final generation = ++_labelGeneration;
    _labelsLoaded = false;
    _isLoadingLabels = true;
    _labelLoadFailed = false;
    _labelSavePending = false;
    _labelSaveScheduled = false;
    _labelScheduleVersion++;
    _isSavingLabels = false;
    _labelSaveFailed = false;
    _latestLabelSave = null;
    _placeNames.clear();
    _typeNames.clear();
    _flavorNames.clear();
    _friendNames.clear();
    _friendReconciliationSignature = null;
    final pending = draft.pendingPlace;
    _isNewPlace = pending != null;
    _placeNameController.text = pending?.name ?? '';
    _addressController.text = pending?.address ?? '';
    _reviewController.text = draft.reviewText;
    final uid = widget.uid;
    final repository = ref.read(checkInLabelRepositoryProvider);
    unawaited(_loadLabels(uid, draft.id, generation, repository));
  }

  Future<void> _loadLabels(
    String uid,
    String draftId,
    int generation,
    CheckInLabelRepository repository,
  ) async {
    try {
      final labels = await repository.load(uid, draftId);
      if (!_isLifecycleCurrent(uid, draftId, generation)) return;
      setState(() {
        for (final entry in labels.placeNames.entries) {
          _placeNames.putIfAbsent(entry.key, () => entry.value);
        }
        for (final entry in labels.typeNames.entries) {
          _typeNames.putIfAbsent(entry.key, () => entry.value);
        }
        for (final entry in labels.flavorNames.entries) {
          _flavorNames.putIfAbsent(entry.key, () => entry.value);
        }
        for (final entry in labels.friendNames.entries) {
          _friendNames.putIfAbsent(entry.key, () => entry.value);
        }
        _labelsLoaded = true;
        _isLoadingLabels = false;
        _labelLoadFailed = false;
        if (_stepError == _labelLoadFailureMessage) _stepError = null;
      });
    } catch (_) {
      if (!_isLifecycleCurrent(uid, draftId, generation)) return;
      setState(() {
        _labelsLoaded = false;
        _isLoadingLabels = false;
        _labelLoadFailed = true;
        _stepError = _labelLoadFailureMessage;
      });
      return;
    }
    if (_labelSavePending) _scheduleLabelSave();
  }

  bool _isLifecycleCurrent(String uid, String draftId, int generation) =>
      mounted &&
      widget.uid == uid &&
      ref.read(currentUidProvider) == uid &&
      _hydratedDraftId == draftId &&
      _labelGeneration == generation &&
      ref.read(checkInFlowProvider(uid)).draft?.id == draftId;

  _CheckInLifecycleSnapshot? _captureLifecycle() {
    final uid = widget.uid;
    final draftId = _hydratedDraftId;
    final generation = _labelGeneration;
    if (draftId == null || !_isLifecycleCurrent(uid, draftId, generation)) {
      return null;
    }
    return (
      uid: uid,
      draftId: draftId,
      generation: generation,
      controller: ref.read(checkInFlowProvider(uid).notifier),
    );
  }

  bool _isSnapshotCurrent(_CheckInLifecycleSnapshot snapshot) =>
      _isLifecycleCurrent(snapshot.uid, snapshot.draftId, snapshot.generation);

  void _persistCurrentMutation(
    Future<void> Function(CheckInFlowController controller) mutation,
  ) {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    unawaited(_ignorePersistence(mutation(lifecycle.controller)));
  }

  void _retryLabelLoad() => _startLabelRecovery(clearFirst: false);

  void _rebuildLabelCache() => _startLabelRecovery(clearFirst: true);

  void _startLabelRecovery({required bool clearFirst}) {
    final draftId = _hydratedDraftId;
    if (draftId == null || _isLoadingLabels) return;
    final uid = widget.uid;
    final generation = ++_labelGeneration;
    final repository = ref.read(checkInLabelRepositoryProvider);
    setState(() {
      _isLoadingLabels = true;
      _labelLoadFailed = false;
      if (_stepError == _labelLoadFailureMessage ||
          _stepError == _unresolvedLabelsMessage) {
        _stepError = null;
      }
    });
    if (!clearFirst) {
      unawaited(_loadLabels(uid, draftId, generation, repository));
      return;
    }
    unawaited(() async {
      try {
        await repository.clear(uid, draftId);
      } catch (_) {
        if (_isLifecycleCurrent(uid, draftId, generation)) {
          setState(() {
            _isLoadingLabels = false;
            _labelLoadFailed = true;
            _stepError = _labelLoadFailureMessage;
          });
        }
        return;
      }
      await _loadLabels(uid, draftId, generation, repository);
    }());
  }

  bool _rememberLabel(Map<String, String> labels, String id, String name) {
    final value = name.trim();
    if (id.isEmpty || value.isEmpty || labels[id] == value) return false;
    labels[id] = value;
    return true;
  }

  void _rememberCatalogLabels(
    CheckInDraft draft, {
    required List<Place> places,
    required List<GelatoType> types,
    required List<Flavor> flavors,
    required List<PublicProfile> friends,
  }) {
    var changed = false;
    for (final place in places) {
      if (place.id == draft.placeId) {
        changed |= _rememberLabel(_placeNames, place.id, place.name);
      }
    }
    for (final type in types) {
      if (type.id == draft.gelatoTypeId) {
        changed |= _rememberLabel(_typeNames, type.id, type.name);
      }
    }
    for (final flavor in flavors) {
      if (draft.flavorIds.contains(flavor.id)) {
        changed |= _rememberLabel(_flavorNames, flavor.id, flavor.name);
      }
    }
    for (final friend in friends) {
      if (draft.taggedUserIds.contains(friend.uid)) {
        changed |= _rememberLabel(_friendNames, friend.uid, friend.displayName);
      }
    }
    if (changed) _scheduleLabelSave();
  }

  void _scheduleLabelSave() {
    _labelSavePending = true;
    if (!_labelsLoaded || _labelSaveScheduled) return;
    _labelSaveScheduled = true;
    final scheduleVersion = ++_labelScheduleVersion;
    final uid = widget.uid;
    final draftId = _hydratedDraftId;
    final generation = _labelGeneration;
    final repository = ref.read(checkInLabelRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scheduleVersion != _labelScheduleVersion) return;
      _labelSaveScheduled = false;
      if (draftId != null && _isLifecycleCurrent(uid, draftId, generation)) {
        _saveLabels(uid, draftId, generation, repository);
      }
    });
  }

  void _saveLabels(
    String uid,
    String draftId,
    int generation,
    CheckInLabelRepository repository,
  ) {
    if (!_isLifecycleCurrent(uid, draftId, generation) ||
        !_labelsLoaded ||
        !_labelSavePending) {
      return;
    }
    _labelSavePending = false;
    final version = ++_labelSaveVersion;
    final labels = CheckInDisplayLabels(
      placeNames: Map<String, String>.unmodifiable(_placeNames),
      typeNames: Map<String, String>.unmodifiable(_typeNames),
      flavorNames: Map<String, String>.unmodifiable(_flavorNames),
      friendNames: Map<String, String>.unmodifiable(_friendNames),
    );
    final previous = _latestLabelSave;
    setState(() {
      _isSavingLabels = true;
      _labelSaveFailed = false;
    });
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A newer snapshot must still be allowed to repair the cache.
        }
      }
      await repository.save(uid, draftId, labels);
    }();
    _latestLabelSave = operation;
    unawaited(
      operation.then<void>(
        (_) => _completeLabelSave(
          uid,
          draftId,
          generation,
          version,
          succeeded: true,
        ),
        onError: (_) => _completeLabelSave(
          uid,
          draftId,
          generation,
          version,
          succeeded: false,
        ),
      ),
    );
  }

  void _completeLabelSave(
    String uid,
    String draftId,
    int generation,
    int version, {
    required bool succeeded,
  }) {
    if (!_isLifecycleCurrent(uid, draftId, generation) ||
        version != _labelSaveVersion) {
      return;
    }
    setState(() {
      _isSavingLabels = false;
      _labelSaveFailed = !succeeded;
      if (succeeded) {
        if (_stepError ==
            AppStrings.checkInLabelsSaveFailed) {
          _stepError = null;
        }
      } else {
        _labelSavePending = true;
        _stepError = AppStrings.checkInLabelsSaveFailed;
      }
    });
    if (succeeded && _labelSavePending) _scheduleLabelSave();
  }

  Future<void> _ignorePersistence(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // Typed failures remain visible in the flow state.
    }
  }

  void _clearLocalError() {
    if (_stepError != null) setState(() => _stepError = null);
  }

  void _clearLocalErrorIf(bool corrected, Iterable<String> messages) {
    if (corrected && messages.contains(_stepError)) _clearLocalError();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    final picker = ImagePicker();
    _clearLocalError();
    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null || !_isSnapshotCurrent(lifecycle)) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (!_isSnapshotCurrent(lifecycle)) return;
      await lifecycle.controller.selectPhoto(
        bytes,
        picked.name.trim().isEmpty ? 'photo.jpg' : picked.name,
      );
      if (!_isSnapshotCurrent(lifecycle)) return;
      final failure = ref.read(checkInFlowProvider(lifecycle.uid)).failure;
      if (failure != null) setState(() => _stepError = failure.message);
    } catch (_) {
      if (!_isSnapshotCurrent(lifecycle)) return;
      final failure = ref.read(checkInFlowProvider(lifecycle.uid)).failure;
      setState(
        () => _stepError =
            failure?.message ?? AppStrings.checkInPhotoCaptureFailed,
      );
    }
  }

  Future<void> _selectE2EPhoto() async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    _clearLocalError();
    try {
      await lifecycle.controller.selectPhoto(
        EmulatorPhotoFixture.bytes,
        EmulatorPhotoFixture.fileName,
      );
      if (!_isSnapshotCurrent(lifecycle)) return;
      final failure = ref.read(checkInFlowProvider(lifecycle.uid)).failure;
      if (failure != null) setState(() => _stepError = failure.message);
    } catch (_) {
      if (!_isSnapshotCurrent(lifecycle)) return;
      final failure = ref.read(checkInFlowProvider(lifecycle.uid)).failure;
      setState(
        () => _stepError =
            failure?.message ?? AppStrings.checkInPhotoCaptureFailed,
      );
    }
  }

  PendingPlaceDraft _pendingPlace({GeoPoint? coordinate}) {
    final current = ref
        .read(checkInFlowProvider(widget.uid))
        .draft
        ?.pendingPlace;
    final point =
        coordinate ??
        (current?.hasCoordinates == true
            ? GeoPoint(current!.latitude!, current.longitude!)
            : null);
    return PendingPlaceDraft(
      name: _placeNameController.text,
      address: _addressController.text,
      latitude: point?.latitude,
      longitude: point?.longitude,
    );
  }

  Future<void> _persistPendingPlace({GeoPoint? coordinate}) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    await _persistPendingPlaceFor(lifecycle, coordinate: coordinate);
  }

  Future<void> _persistPendingPlaceFor(
    _CheckInLifecycleSnapshot lifecycle, {
    GeoPoint? coordinate,
  }) async {
    if (!_isSnapshotCurrent(lifecycle)) return;
    _clearLocalErrorIf(
      _placeNameController.text.trim().isNotEmpty &&
          _addressController.text.trim().isNotEmpty,
      const <String>[_missingPlaceFields],
    );
    await _ignorePersistence(
      lifecycle.controller.setPendingPlace(
        _pendingPlace(coordinate: coordinate),
      ),
    );
  }

  void _selectPlace(String value) {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    _clearLocalError();
    setState(() {
      _isNewPlace = value == checkInNewPlaceValue;
      _showMap = false;
    });
    if (_isNewPlace) {
      unawaited(_persistPendingPlaceFor(lifecycle));
    } else {
      unawaited(
        _ignorePersistence(lifecycle.controller.selectExistingPlace(value)),
      );
    }
  }

  Future<void> _useGps() async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    await _persistPendingPlaceFor(lifecycle);
    if (!_isSnapshotCurrent(lifecycle)) return;
    await _resolvePlaceAndAdvance(lifecycle);
  }

  Future<bool> _resolvePlaceAndAdvance(
    _CheckInLifecycleSnapshot lifecycle,
  ) async {
    if (!_isSnapshotCurrent(lifecycle)) return false;
    final pendingName = _placeNameController.text;
    try {
      final id = await lifecycle.controller.resolvePendingPlace();
      if (!_isSnapshotCurrent(lifecycle) || id == null) return false;
      if (_rememberLabel(_placeNames, id, pendingName)) {
        _scheduleLabelSave();
      }
      setState(() {
        _isNewPlace = false;
        _showMap = false;
        _stepError = null;
      });
      await lifecycle.controller.setStep(2);
      return _isSnapshotCurrent(lifecycle);
    } on CheckInFlowFailure catch (error) {
      if (_isSnapshotCurrent(lifecycle)) {
        setState(() {
          _stepError = error.message;
          _showMap = true;
        });
      }
      return false;
    }
  }

  Future<void> _continue(CheckInFlowState flow) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null || flow.draft?.id != lifecycle.draftId) return;
    final draft = flow.draft!;
    setState(() => _stepError = null);
    try {
      switch (draft.currentStep) {
        case 0:
          if (draft.stagingObjectPath == null || flow.photoMissing) {
            setState(
              () => _stepError =
                  AppStrings.checkInAddPhotoFirst,
            );
            return;
          }
        case 1:
          final latest = ref.read(checkInFlowProvider(lifecycle.uid)).draft;
          if (latest == null || latest.id != lifecycle.draftId) return;
          if (_isNewPlace && latest.placeId == null) {
            final pending = _pendingPlace();
            if (pending.name.isEmpty || pending.address.isEmpty) {
              setState(() => _stepError = _missingPlaceFields);
              return;
            }
            await lifecycle.controller.setPendingPlace(pending);
            if (!_isSnapshotCurrent(lifecycle)) return;
            await _resolvePlaceAndAdvance(lifecycle);
            return;
          }
          if (latest.placeId == null) {
            setState(() => _stepError = AppStrings.checkInSelectPlace);
            return;
          }
          if (!_placeLabelResolved(latest)) {
            _showUnresolvedLabelsError();
            return;
          }
        case 2:
          final latest = ref.read(checkInFlowProvider(lifecycle.uid)).draft;
          if (latest == null || latest.id != lifecycle.draftId) return;
          if (latest.gelatoTypeId == null) {
            setState(() => _stepError = _missingType);
            return;
          }
          if (latest.flavorIds.isEmpty || latest.flavorIds.length > 4) {
            setState(() => _stepError = _invalidFlavors);
            return;
          }
          if (!_gelatoLabelsResolved(latest)) {
            _showUnresolvedLabelsError();
            return;
          }
        case 3:
          if (draft.rating == null) {
            setState(() => _stepError = _missingRating);
            return;
          }
          if (!_reviewLabelsResolved(draft)) {
            _showUnresolvedLabelsError();
            return;
          }
        case 4:
          if (!_reviewLabelsResolved(draft)) {
            _showUnresolvedLabelsError();
            return;
          }
          if (!await _reconcileAcceptedFriendsBeforePublish(lifecycle)) return;
          if (!_isSnapshotCurrent(lifecycle)) return;
          await _publish(lifecycle);
          return;
      }
      if (!_isSnapshotCurrent(lifecycle)) return;
      await lifecycle.controller.setStep(draft.currentStep + 1);
    } on CheckInFlowFailure catch (error) {
      if (_isSnapshotCurrent(lifecycle)) {
        setState(() => _stepError = error.message);
      }
    } on FormatException {
      if (_isSnapshotCurrent(lifecycle)) {
        setState(
          () => _stepError = AppStrings.checkInCheckStepData,
        );
      }
    }
  }

  void _primaryAction(CheckInFlowState flow) {
    final draft = flow.draft;
    if (_labelLoadFailed && draft != null && _labelRecoveryBlocks(draft)) {
      _retryLabelLoad();
      return;
    }
    if (_friendsVerificationPending) {
      _retryFriends();
      return;
    }
    if (_labelSaveFailed && draft?.currentStep == 4) {
      _scheduleLabelSave();
      return;
    }
    if (draft?.currentStep == 4 &&
        flow.isDirty &&
        flow.failure?.kind == CheckInFlowFailureKind.persistence) {
      unawaited(_retryDraftSave(flow));
      return;
    }
    unawaited(_continue(flow));
  }

  Future<void> _retryDraftSave(CheckInFlowState flow) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null || flow.draft?.id != lifecycle.draftId) return;
    await _ignorePersistence(lifecycle.controller.retryDraftSave());
  }

  bool _placeLabelResolved(CheckInDraft draft) {
    final placeId = draft.placeId;
    return placeId == null || _placeNames.containsKey(placeId);
  }

  bool _gelatoLabelsResolved(CheckInDraft draft) {
    final typeId = draft.gelatoTypeId;
    if (typeId != null && !_typeNames.containsKey(typeId)) return false;
    for (final flavorId in draft.flavorIds) {
      if (!_flavorNames.containsKey(flavorId)) return false;
    }
    return true;
  }

  bool _reviewLabelsResolved(CheckInDraft draft) {
    if (draft.placeId == null ||
        draft.gelatoTypeId == null ||
        draft.flavorIds.isEmpty) {
      return false;
    }
    if (!_placeLabelResolved(draft) || !_gelatoLabelsResolved(draft)) {
      return false;
    }
    for (final uid in draft.taggedUserIds) {
      if (!_friendNames.containsKey(uid)) return false;
    }
    return true;
  }

  bool _currentStepLabelsResolved(CheckInDraft draft) =>
      switch (draft.currentStep) {
        1 => _placeLabelResolved(draft),
        2 => _gelatoLabelsResolved(draft),
        4 => _reviewLabelsResolved(draft),
        _ => true,
      };

  bool _labelRecoveryBlocks(CheckInDraft draft) =>
      draft.currentStep == 4 || !_currentStepLabelsResolved(draft);

  void _showUnresolvedLabelsError() {
    if (_isLoadingLabels) return;
    setState(
      () => _stepError = _labelLoadFailed
          ? _labelLoadFailureMessage
          : _unresolvedLabelsMessage,
    );
  }

  Future<void> _back(CheckInDraft draft) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null || draft.id != lifecycle.draftId) return;
    setState(() => _stepError = null);
    if (draft.currentStep > 0) {
      await _ignorePersistence(
        lifecycle.controller.setStep(draft.currentStep - 1),
      );
    } else if (mounted) {
      _close();
    }
  }

  void _close() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      unawaited(navigator.maybePop());
    } else {
      widget.onExit();
    }
  }

  Future<bool> _reconcileAcceptedFriendsBeforePublish(
    _CheckInLifecycleSnapshot lifecycle,
  ) async {
    if (!_isSnapshotCurrent(lifecycle)) return false;
    final friends = ref.read(acceptedFriendProfilesProvider);
    final draft = ref.read(checkInFlowProvider(lifecycle.uid)).draft;
    if (draft == null || draft.id != lifecycle.draftId) return false;
    if (draft.taggedUserIds.isEmpty) {
      _friendsVerificationPending = false;
      return true;
    }
    if (friends is! AsyncData<List<PublicProfile>>) {
      setState(() {
        _friendsVerificationPending = true;
        _stepError = _friendsVerificationMessage;
      });
      return false;
    }
    _friendsVerificationPending = false;
    final accepted = friends.value.map((profile) => profile.uid).toSet();
    final reconciled = draft.taggedUserIds
        .where(accepted.contains)
        .toList(growable: false);
    if (!_sameStrings(reconciled, draft.taggedUserIds)) {
      await lifecycle.controller.setTaggedUsers(reconciled);
      if (!_isSnapshotCurrent(lifecycle)) return false;
    }
    return _isSnapshotCurrent(lifecycle);
  }

  Future<void> _publish([_CheckInLifecycleSnapshot? lifecycle]) async {
    final uid = lifecycle?.uid ?? widget.uid;
    final generation = lifecycle?.generation ?? _labelGeneration;
    final CheckInFlowController controller = lifecycle == null
        ? ref.read(checkInFlowProvider(uid).notifier)
        : lifecycle.controller;
    if (lifecycle != null && !_isSnapshotCurrent(lifecycle)) return;
    try {
      await controller.publish();
      final current = lifecycle == null
          ? _isUidGenerationCurrent(uid, generation)
          : _isSnapshotCurrent(lifecycle);
      if (current) setState(() => _stepError = null);
    } on CheckInFlowFailure catch (error) {
      final current = lifecycle == null
          ? _isUidGenerationCurrent(uid, generation)
          : _isSnapshotCurrent(lifecycle);
      if (current) setState(() => _stepError = error.message);
    }
  }

  Future<Flavor> _createFlavor(String name) async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) throw StateError(_flavorCreationFailure);
    final service = ref.read(flavorServiceProvider);
    try {
      final flavor = await service.addFlavor(name);
      if (!_isSnapshotCurrent(lifecycle)) {
        throw StateError(_flavorCreationFailure);
      }
      if (_rememberLabel(_flavorNames, flavor.id, flavor.name)) {
        _scheduleLabelSave();
      }
      _clearLocalErrorIf(true, const <String>[_flavorCreationFailure]);
      return flavor;
    } catch (_) {
      if (_isSnapshotCurrent(lifecycle)) {
        setState(() => _stepError = _flavorCreationFailure);
      }
      throw StateError(_flavorCreationFailure);
    }
  }

  Future<void> _retryPhotoUpload() async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    await _ignorePersistence(lifecycle.controller.retryPhotoUpload());
    if (!_isSnapshotCurrent(lifecycle)) return;
    final failure = ref.read(checkInFlowProvider(lifecycle.uid)).failure;
    _clearLocalErrorIf(
      failure?.kind != CheckInFlowFailureKind.photo,
      const <String>[_photoUploadFailure],
    );
  }

  Future<void> _removePhoto() async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    await _ignorePersistence(lifecycle.controller.removePhoto());
  }

  Future<void> _retryRestoredPhotoRead() async {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    await _ignorePersistence(lifecycle.controller.retryRestoredPhotoRead());
  }

  void _scheduleInitialPreselections(CheckInDraft draft, List<Place> places) {
    final requestedPlace = widget.placeId;
    final shouldApplyPlace =
        !_placePreselectionScheduled &&
        requestedPlace != null &&
        draft.placeId == null &&
        draft.pendingPlace == null &&
        places.any((place) => place.id == requestedPlace);
    if (!shouldApplyPlace) return;
    _placePreselectionScheduled = true;
    final uid = widget.uid;
    final draftId = draft.id;
    final generation = _labelGeneration;
    final controller = ref.read(checkInFlowProvider(uid).notifier);
    final placeIds = places.map((place) => place.id).toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLifecycleCurrent(uid, draftId, generation)) return;
      unawaited(
        _ignorePersistence(
          controller.applyPlacePreselection(requestedPlace, placeIds),
        ),
      );
    });
  }

  void _scheduleAcceptedFriendsSync(
    CheckInDraft draft,
    List<PublicProfile> friends,
  ) {
    final accepted = friends.map((profile) => profile.uid).toList()..sort();
    final signature = <String>[
      draft.id,
      ...accepted,
      '|',
      ...draft.taggedUserIds,
      '|${widget.prefillFriendId ?? ''}',
      '|$_friendPreselectionScheduled',
    ].join('\u0000');
    if (_friendReconciliationSignature == signature) return;
    _friendReconciliationSignature = signature;
    final uid = widget.uid;
    final draftId = draft.id;
    final generation = _labelGeneration;
    final requested = widget.prefillFriendId;
    final controller = ref.read(checkInFlowProvider(uid).notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLifecycleCurrent(uid, draftId, generation)) return;
      final current = ref.read(checkInFlowProvider(uid)).draft;
      if (current == null || current.id != draft.id) return;
      final acceptedIds = accepted.toSet();
      final next = current.taggedUserIds.where(acceptedIds.contains).toList();
      if (!_friendPreselectionScheduled &&
          next.isEmpty &&
          requested != null &&
          acceptedIds.contains(requested)) {
        next.add(requested);
        _friendPreselectionScheduled = true;
      }
      if (_sameStrings(next, current.taggedUserIds)) return;
      unawaited(_ignorePersistence(controller.setTaggedUsers(next)));
    });
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _retryFriends() {
    ref.read(retryFriendshipSourcesProvider)();
  }

  void _clearSelectedFriends() {
    final lifecycle = _captureLifecycle();
    if (lifecycle == null) return;
    setState(() {
      _friendsVerificationPending = false;
      if (_stepError == _friendsVerificationMessage) _stepError = null;
    });
    unawaited(
      _ignorePersistence(lifecycle.controller.setTaggedUsers(const <String>[])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(checkInFlowProvider(widget.uid));
    final placesAsync = ref.watch(placesProvider);
    final friendsAsync = ref.watch(acceptedFriendProfilesProvider);

    ref.listen<CheckInFlowState>(checkInFlowProvider(widget.uid), (_, next) {
      if (!next.published || _didComplete) return;
      _didComplete = true;
      final uid = widget.uid;
      final draftId = next.publicationDraftId ?? _hydratedDraftId;
      final generation = _labelGeneration;
      final repository = ref.read(checkInLabelRepositoryProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isUidGenerationCurrent(uid, generation)) {
          unawaited(_finishCompletion(uid, draftId, generation, repository));
        }
      });
    });
    ref.listen(placesProvider, (_, next) {
      final places = next.value;
      final draft = ref.read(checkInFlowProvider(widget.uid)).draft;
      if (draft != null && places != null) {
        _scheduleInitialPreselections(draft, places);
      }
    });
    ref.listen(acceptedFriendProfilesProvider, (_, next) {
      final draft = ref.read(checkInFlowProvider(widget.uid)).draft;
      if (draft != null) {
        if (next case AsyncData<List<PublicProfile>>(:final value)) {
          _scheduleAcceptedFriendsSync(draft, value);
          if (_friendsVerificationPending) {
            final uid = widget.uid;
            final draftId = draft.id;
            final generation = _labelGeneration;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isLifecycleCurrent(uid, draftId, generation)) return;
              setState(() {
                _friendsVerificationPending = false;
                if (_stepError == _friendsVerificationMessage) {
                  _stepError = null;
                }
              });
            });
          }
        }
      }
    });

    if (flow.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (flow.published) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check_circle, size: 64, color: AppTheme.mentaGlaciale),
              SizedBox(height: 16),
              Text(AppStrings.checkInPublished),
            ],
          ),
        ),
      );
    }
    if (flow.publishedPendingClear && flow.draft == null) {
      return _PublishedRecovery(
        busy: flow.isPublishing,
        message: _stepError ?? flow.failure?.message,
        onRetry: _publish,
      );
    }
    final draft = flow.draft;
    if (draft == null) {
      return Scaffold(
        body: Center(
          child: Text(flow.failure?.message ?? AppStrings.checkInDraftUnavailable),
        ),
      );
    }
    _hydrate(draft);
    final places = placesAsync.value ?? const <Place>[];
    final types = ref.watch(gelatoTypesProvider).value ?? defaultGelatoTypes;
    final flavors = ref.watch(flavorsProvider).value ?? const <Flavor>[];
    final friends = friendsAsync.value ?? const <PublicProfile>[];
    _rememberCatalogLabels(
      draft,
      places: places,
      types: types,
      flavors: flavors,
      friends: friends,
    );
    _scheduleInitialPreselections(draft, places);
    if (friendsAsync case AsyncData<List<PublicProfile>>(:final value)) {
      _scheduleAcceptedFriendsSync(draft, value);
    }
    final canExit =
        !flow.isDirty &&
        !flow.isEditorLocked &&
        !flow.isUploading &&
        !_labelSavePending &&
        !_isSavingLabels;
    final waitingForRequiredLabels =
        _isLoadingLabels && _labelRecoveryBlocks(draft);
    final waitingForLabelPersistence =
        draft.currentStep == 4 &&
        !_labelSaveFailed &&
        !_labelLoadFailed &&
        !_isLoadingLabels &&
        (_labelSavePending || _isSavingLabels);

    return PopScope<void>(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !canExit) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_guardMessage(flow))));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GelatoBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1024;
              return Column(
                children: <Widget>[
                  _Header(onClose: canExit ? _close : null),
                  if (!wide) CheckInProgress(currentStep: draft.currentStep),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (wide)
                          CheckInStepRail(currentStep: draft.currentStep),
                        Expanded(
                          child: AbsorbPointer(
                            key: const Key('check-in-editor-lock'),
                            absorbing: flow.isEditorLocked,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                wide ? 36 : 20,
                                wide ? 28 : 14,
                                wide ? 36 : 20,
                                32,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 720,
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey<String>(
                                      'check-in-form',
                                    ),
                                    width: double.infinity,
                                    child: _buildPage(flow, draft, places),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: CheckInNavigation(
          backLabel: draft.currentStep == 0 ? 'Chiudi' : 'Indietro',
          primaryLabel: _primaryLabel(flow, draft),
          onBack:
              flow.isEditorLocked ||
                  flow.isSaving ||
                  flow.isUploading ||
                  _labelSavePending ||
                  _isSavingLabels
              ? null
              : () => _back(draft),
          onPrimary:
              flow.isUploading ||
                  flow.isPublishing ||
                  flow.isResolvingPlace ||
                  flow.isSaving ||
                  waitingForLabelPersistence ||
                  waitingForRequiredLabels
              ? null
              : () => _primaryAction(flow),
          busy: flow.isPublishing || flow.isResolvingPlace,
        ),
      ),
    );
  }

  bool _isUidGenerationCurrent(String uid, int generation) =>
      mounted &&
      widget.uid == uid &&
      ref.read(currentUidProvider) == uid &&
      _labelGeneration == generation;

  Future<void> _finishCompletion(
    String uid,
    String? draftId,
    int generation,
    CheckInLabelRepository repository,
  ) async {
    if (draftId != null) {
      try {
        await repository.clear(uid, draftId);
      } catch (_) {
        // The published check-in must still complete if cache cleanup fails.
      }
    }
    if (_isUidGenerationCurrent(uid, generation)) widget.onCompleted();
  }

  Widget _buildPage(
    CheckInFlowState flow,
    CheckInDraft draft,
    List<Place> places,
  ) {
    final content = switch (draft.currentStep) {
      0 => PhotoStep(
        bytes: flow.photoBytes,
        hasStagedPhoto: draft.stagingObjectPath != null,
        isUploading: flow.isUploading,
        photoMissing: flow.photoMissing,
        uploadFailed:
            !flow.isUploading &&
            flow.failure?.kind == CheckInFlowFailureKind.photo &&
            flow.photoBytes != null &&
            draft.stagingObjectPath == null &&
            !flow.photoMissing,
        onCamera: flow.isUploading
            ? null
            : () => _pickPhoto(ImageSource.camera),
        onGallery: flow.isUploading
            ? null
            : () => _pickPhoto(ImageSource.gallery),
        onRemove: flow.isUploading ? null : _removePhoto,
        onRetry: () => unawaited(_retryRestoredPhotoRead()),
        onRetryUpload: () => unawaited(_retryPhotoUpload()),
        onE2EPhoto: flow.isUploading ? null : _selectE2EPhoto,
      ),
      1 => PlaceStep(
        places: places,
        selectedPlaceId: draft.placeId,
        cachedSelectedPlaceName: _placeNames[draft.placeId],
        isNewPlace: _isNewPlace,
        nameController: _placeNameController,
        addressController: _addressController,
        selectedCoordinate: draft.pendingPlace?.hasCoordinates == true
            ? GeoPoint(
                draft.pendingPlace!.latitude!,
                draft.pendingPlace!.longitude!,
              )
            : null,
        showMap: _showMap,
        enabled: !flow.isResolvingPlace,
        onSelectionChanged: _selectPlace,
        onInputChanged: () => unawaited(_persistPendingPlace()),
        onUseGps: () => unawaited(_useGps()),
        onShowMap: () => setState(() => _showMap = true),
        onMapSelected: (coordinate) {
          setState(() {
            _showMap = true;
            if (_stepError == _invalidPlaceLocation) _stepError = null;
          });
          unawaited(_persistPendingPlace(coordinate: coordinate));
        },
      ),
      2 => _gelatoPage(flow, draft),
      3 => ExperienceStep(
        rating: draft.rating,
        reviewController: _reviewController,
        enabled: !flow.isEditorLocked,
        onRatingChanged: (rating) {
          _clearLocalErrorIf(true, const <String>[_missingRating]);
          _persistCurrentMutation((controller) => controller.setRating(rating));
        },
        onReviewChanged: (review) {
          _persistCurrentMutation(
            (controller) => controller.setReviewText(review),
          );
        },
        consumedAt: draft.consumedAt,
        onConsumedAtChanged: (consumedAt) {
          _persistCurrentMutation(
            (controller) => controller.setConsumedAt(consumedAt),
          );
        },
      ),
      4 =>
        _reviewLabelsResolved(draft)
            ? _sharePage(flow, draft)
            : const _UnresolvedLabelsNotice(),
      _ => const SizedBox.shrink(),
    };
    final failureMessage = _stepError ?? flow.failure?.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          checkInStepLabels[draft.currentStep],
          key: Key('check-in-step-title-${draft.currentStep}'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        content,
        if (_labelLoadFailed) ...<Widget>[
          const SizedBox(height: 16),
          _LabelRecoveryActions(
            busy: _isLoadingLabels,
            onRetry: _retryLabelLoad,
            onRebuild: _rebuildLabelCache,
          ),
        ],
        if (failureMessage != null) ...<Widget>[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              failureMessage,
              key: const Key('check-in-step-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _gelatoPage(CheckInFlowState flow, CheckInDraft draft) {
    final typesAsync = ref.watch(gelatoTypesProvider);
    final flavorsAsync = ref.watch(flavorsProvider);
    final types = List<GelatoType>.of(typesAsync.value ?? defaultGelatoTypes);
    final selectedTypeId = draft.gelatoTypeId;
    final cachedTypeName = _typeNames[selectedTypeId];
    if (selectedTypeId != null &&
        cachedTypeName != null &&
        !types.any((type) => type.id == selectedTypeId)) {
      types.add(
        GelatoType(
          id: selectedTypeId,
          name: cachedTypeName,
          sortOrder: types.length,
        ),
      );
    }
    final flavors = List<Flavor>.of(flavorsAsync.value ?? const <Flavor>[]);
    for (final flavorId in draft.flavorIds) {
      final cachedName = _flavorNames[flavorId];
      if (cachedName != null &&
          !flavors.any((flavor) => flavor.id == flavorId)) {
        flavors.add(Flavor(id: flavorId, name: cachedName));
      }
    }
    return GelatoStep(
      key: ValueKey<String>('check-in-gelato-${draft.id}'),
      types: types,
      flavors: flavors,
      selectedTypeId: draft.gelatoTypeId,
      selectedFlavorIds: draft.flavorIds,
      catalogWarning: typesAsync.hasError
          ? AppStrings.checkInCatalogFallback
          : null,
      flavorsLoading: flavorsAsync.isLoading,
      flavorsFailure: flavorsAsync.hasError
          ? AppStrings.checkInFlavorCatalogError
          : null,
      enabled: !flow.isEditorLocked,
      onTypeSelected: (type) {
        _clearLocalErrorIf(true, const <String>[_missingType]);
        _persistCurrentMutation(
          (controller) => controller.setGelatoType(type.id),
        );
      },
      onFlavorsChanged: (ids) {
        _clearLocalErrorIf(ids.isNotEmpty && ids.length <= 4, const <String>[
          _invalidFlavors,
          AppStrings.checkInMaxFlavors,
        ]);
        _persistCurrentMutation((controller) => controller.setFlavorIds(ids));
      },
      onCreateFlavor: _createFlavor,
      onFlavorLimit: () => setState(() => _stepError = AppStrings.checkInMaxFlavors),
    );
  }

  Widget _sharePage(CheckInFlowState flow, CheckInDraft draft) {
    final friends = ref.watch(acceptedFriendProfilesProvider);
    final placeName = _placeNames[draft.placeId];
    final typeName = _typeNames[draft.gelatoTypeId];
    final flavorsById = <String, Flavor>{
      for (final flavor in ref.watch(flavorsProvider).value ?? const <Flavor>[])
        flavor.id: flavor,
    };
    return ShareStep(
      placeName: placeName!,
      typeName: typeName!,
      flavorNames: draft.flavorIds.map((id) => _flavorNames[id]!).toList(),
      shareFlavors: draft.flavorIds
          .map(
            (id) => <String, dynamic>{
              'name': _flavorNames[id] ?? flavorsById[id]?.name ?? '',
              'color_hex': flavorsById[id]?.colorHex,
            },
          )
          .toList(),
      rating: draft.rating ?? 0,
      reviewText: draft.reviewText,
      hasPrivatePhoto: draft.stagingObjectPath != null && !flow.photoMissing,
      photoBytes: flow.photoBytes,
      friends: friends,
      selectedFriendIds: draft.taggedUserIds,
      selectedFriendNames: draft.taggedUserIds
          .map((uid) => _friendNames[uid]!)
          .toList(),
      enabled: !flow.isEditorLocked,
      onFriendChanged: (uid, selected) {
        _clearLocalError();
        final next = selected
            ? <String>{...draft.taggedUserIds, uid}.toList()
            : draft.taggedUserIds.where((id) => id != uid).toList();
        _persistCurrentMutation(
          (controller) => controller.setTaggedUsers(next),
        );
      },
      onRetryFriends: _retryFriends,
      onClearSelectedFriends: _clearSelectedFriends,
      publicationFailed:
          flow.failure?.kind == CheckInFlowFailureKind.publication,
    );
  }

  String _primaryLabel(CheckInFlowState flow, CheckInDraft draft) {
    if (_labelLoadFailed && _labelRecoveryBlocks(draft)) {
      return AppStrings.checkInRetryLabels;
    }
    if (_labelSaveFailed && draft.currentStep == 4) {
      return AppStrings.checkInRetrySave;
    }
    if (_isLoadingLabels && _labelRecoveryBlocks(draft)) {
      return AppStrings.checkInLoadingLabels;
    }
    if (draft.currentStep == 4 &&
        ((_labelSavePending && !_labelSaveFailed) || _isSavingLabels)) {
      return AppStrings.checkInSavingLabels;
    }
    if (!_currentStepLabelsResolved(draft)) return AppStrings.checkInVerifyLabels;
    if (draft.currentStep != 4) return 'Continua';
    if (flow.publishedPendingClear) return AppStrings.checkInRetryCleanup;
    if (flow.publicationFailedPendingClear) return AppStrings.checkInCompleteUnlock;
    if (flow.publicationCallingPendingRetry) return AppStrings.retry;
    if (_friendsVerificationPending) return AppStrings.checkInRetryFriends;
    if (flow.failure?.kind == CheckInFlowFailureKind.publication) {
      return AppStrings.retry;
    }
    if (flow.failure?.kind == CheckInFlowFailureKind.persistence) {
      return AppStrings.retry;
    }
    return 'Pubblica';
  }

  String _guardMessage(CheckInFlowState flow) {
    if (flow.publishedPendingClear) {
      return AppStrings.checkInCompleteCleanupHint;
    }
    if (flow.publicationFailedPendingClear) {
      return AppStrings.checkInCompleteUnlockHint;
    }
    if (flow.isResolvingPlace) {
      return AppStrings.checkInAwaitPlace;
    }
    if (flow.isUploading) {
      return AppStrings.checkInAwaitPhoto;
    }
    if (_labelSavePending || _isSavingLabels) {
      return AppStrings.checkInAwaitLabels;
    }
    return AppStrings.checkInAwaitDraft;
  }
}

final class _UnresolvedLabelsNotice extends StatelessWidget {
  const _UnresolvedLabelsNotice();

  @override
  Widget build(BuildContext context) => const Card(
    key: ValueKey<String>('check-in-page-4'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Text(
        AppStrings.checkInSummaryUnavailable,
      ),
    ),
  );
}

final class _LabelRecoveryActions extends StatelessWidget {
  const _LabelRecoveryActions({
    required this.busy,
    required this.onRetry,
    required this.onRebuild,
  });

  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRebuild;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      OutlinedButton(
        onPressed: busy ? null : onRetry,
        child: const Text(AppStrings.checkInRetryLabels),
      ),
      TextButton(
        onPressed: busy ? null : onRebuild,
        child: const Text(AppStrings.checkInRebuildCache),
      ),
    ],
  );
}

final class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
    child: Row(
      children: <Widget>[
        IconButton(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: onClose,
          tooltip: AppStrings.checkInCloseTooltip,
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.checkInTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

final class _PublishedRecovery extends StatelessWidget {
  const _PublishedRecovery({
    required this.busy,
    required this.message,
    required this.onRetry,
  });

  final bool busy;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: GelatoBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 64,
                    color: AppTheme.mentaGlaciale,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.checkInAlreadyPublished,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ??
                        AppStrings.checkInCompleteCleanupToClose,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: busy ? null : onRetry,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(AppStrings.checkInCompleteCleanup),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
