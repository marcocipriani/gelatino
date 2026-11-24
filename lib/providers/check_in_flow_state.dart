import 'dart:typed_data';

import '../models/check_in_draft.dart';

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
    this.uploadProgress,
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

  /// Fraction of the staging upload sent, while [isUploading]. Null before
  /// the bytes start moving (compression) and when the platform reports none.
  final double? uploadProgress;
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
    Object? uploadProgress = _flowUnset,
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
    uploadProgress: identical(uploadProgress, _flowUnset)
        ? this.uploadProgress
        : uploadProgress as double?,
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
