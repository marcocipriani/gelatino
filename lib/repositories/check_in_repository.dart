import 'package:cloud_functions/cloud_functions.dart';

import '../models/check_in_draft.dart';

enum PublishCheckInStatus { created, existing }

final class PublishCheckInResult {
  const PublishCheckInResult(this.checkInId, this.status);

  final String checkInId;
  final PublishCheckInStatus status;

  @override
  bool operator ==(Object other) =>
      other is PublishCheckInResult &&
      other.checkInId == checkInId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(checkInId, status);
}

final class CheckInCallableException implements Exception {
  const CheckInCallableException(this.code, [this.reason]);

  final String code;

  /// Machine-readable cause from the callable (`CheckInFailureReason` in
  /// functions/src/services/check_ins.ts), when the backend sent one.
  final String? reason;
}

String? _reasonOf(Object? details) {
  if (details is! Map) return null;
  final reason = details['reason'];
  return reason is String ? reason : null;
}

abstract interface class CheckInCallableDataSource {
  Future<Object?> call(String name, Map<String, Object?> payload);
}

final class FirebaseCheckInCallableDataSource
    implements CheckInCallableDataSource {
  const FirebaseCheckInCallableDataSource(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Object?> call(String name, Map<String, Object?> payload) async {
    try {
      return (await _functions.httpsCallable(name).call<Object?>(payload)).data;
    } on FirebaseFunctionsException catch (error) {
      throw CheckInCallableException(error.code, _reasonOf(error.details));
    }
  }
}

abstract interface class CheckInRepository {
  Future<PublishCheckInResult> publish(CheckInDraft draft);

  Future<void> delete(String checkInId);
}

final class CallableCheckInRepository implements CheckInRepository {
  const CallableCheckInRepository(this._source);

  final CheckInCallableDataSource _source;

  @override
  Future<PublishCheckInResult> publish(CheckInDraft draft) async {
    if (!draft.isPublishable) {
      throw const CheckInValidationFailure(
        'Completa tutti i campi obbligatori prima di pubblicare.',
      );
    }
    final payload = <String, Object?>{
      'checkInId': draft.id,
      'placeId': draft.placeId,
      'gelatoTypeId': draft.gelatoTypeId,
      'flavorIds': draft.flavorIds,
      'rating': draft.rating,
      'reviewText': draft.reviewText.trim(),
      'taggedUserIds': draft.taggedUserIds,
      'stagingObjectPath': draft.stagingObjectPath,
      // Omitted unless the user backdated the check-in: the server then stamps
      // the publication time, which is what every ordinary check-in wants.
      if (draft.consumedAt case final consumed?)
        'consumedAtMs': consumed.millisecondsSinceEpoch,
    };
    try {
      final value = await _source.call('createCheckIn', payload);
      return _parseResult(value, draft.id);
    } on CheckInCallableException catch (error) {
      throw _failureFor(error.code, error.reason);
    }
  }

  @override
  Future<void> delete(String checkInId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(checkInId)) {
      throw const CheckInValidationFailure('ID check-in non valido.');
    }
    try {
      await _source.call('deleteCheckIn', <String, Object?>{
        'checkInId': checkInId,
      });
    } on CheckInCallableException catch (error) {
      throw _failureFor(error.code, error.reason);
    }
  }
}

PublishCheckInResult _parseResult(Object? value, String expectedId) {
  if (value is! Map) {
    throw const CheckInProtocolFailure('Risposta di pubblicazione non valida.');
  }
  final normalized = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const CheckInProtocolFailure(
        'Risposta di pubblicazione non valida.',
      );
    }
    normalized[entry.key as String] = entry.value;
  }
  if (normalized.length != 2 ||
      !normalized.containsKey('checkInId') ||
      !normalized.containsKey('status') ||
      normalized['checkInId'] != expectedId) {
    throw const CheckInProtocolFailure('Risposta di pubblicazione non valida.');
  }
  final status = switch (normalized['status']) {
    'created' => PublishCheckInStatus.created,
    'existing' => PublishCheckInStatus.existing,
    _ => throw const CheckInProtocolFailure(
      'Stato di pubblicazione non valido.',
    ),
  };
  return PublishCheckInResult(expectedId, status);
}

sealed class CheckInFailure implements Exception {
  const CheckInFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CheckInAuthenticationFailure extends CheckInFailure {
  const CheckInAuthenticationFailure()
    : super('Accedi di nuovo per pubblicare il check-in.');
}

final class CheckInPermissionFailure extends CheckInFailure {
  const CheckInPermissionFailure()
    : super('Non hai i permessi per pubblicare questo check-in.');
}

final class CheckInValidationFailure extends CheckInFailure {
  const CheckInValidationFailure(super.message);
}

final class CheckInMediaMissingFailure extends CheckInFailure {
  const CheckInMediaMissingFailure([
    super.message =
        'La foto privata non è più disponibile. Selezionala di nuovo.',
  ]);
}

final class CheckInPreconditionFailure extends CheckInFailure {
  const CheckInPreconditionFailure([
    super.message =
        'Il check-in non può essere pubblicato nello stato attuale.',
  ]);
}

final class CheckInRetryableFailure extends CheckInFailure {
  const CheckInRetryableFailure()
    : super('Pubblicazione interrotta. Riprova senza ricreare il check-in.');
}

final class CheckInRemoteFailure extends CheckInFailure {
  const CheckInRemoteFailure()
    : super('Errore remoto durante la pubblicazione del check-in.');
}

final class CheckInProtocolFailure extends CheckInFailure {
  const CheckInProtocolFailure(super.message);
}

CheckInFailure _failureFor(String code, [String? reason]) {
  final byReason = _failureForReason(reason);
  if (byReason != null) return byReason;
  return switch (code) {
    'unauthenticated' => const CheckInAuthenticationFailure(),
    'permission-denied' => const CheckInPermissionFailure(),
    'invalid-argument' => const CheckInValidationFailure(
      'I dati del check-in non sono validi.',
    ),
    'not-found' => const CheckInMediaMissingFailure(),
    'failed-precondition' => const CheckInPreconditionFailure(),
    'unavailable' ||
    'deadline-exceeded' ||
    'internal' => const CheckInRetryableFailure(),
    _ => const CheckInRemoteFailure(),
  };
}

/// Maps `CheckInFailureReason` (functions/src/services/check_ins.ts) to a
/// message that says what happened and what to do next. Unknown or absent
/// reasons fall back to the coarse status-code mapping.
CheckInFailure? _failureForReason(String? reason) => switch (reason) {
  'photo_missing' => const CheckInMediaMissingFailure(),
  'photo_invalid' => const CheckInMediaMissingFailure(
    'La foto non è utilizzabile: serve un JPEG sotto i 5 MB. Scegline '
    'un’altra.',
  ),
  'place_missing' => const CheckInPreconditionFailure(
    'La gelateria scelta non esiste più. Torna al passo Luogo e '
    'selezionane un’altra.',
  ),
  'gelato_type_missing' => const CheckInPreconditionFailure(
    'Il tipo di gelato scelto non è più disponibile. Torna al passo '
    'Gelato e selezionane un altro.',
  ),
  'flavor_missing' => const CheckInPreconditionFailure(
    'Uno dei gusti scelti non è più disponibile. Torna al passo Gelato e '
    'selezionane un altro.',
  ),
  'catalog_invalid' => const CheckInPreconditionFailure(
    'I dati della gelateria o del gusto non sono validi. Riprova con '
    'un’altra selezione.',
  ),
  'profile_missing' => const CheckInPreconditionFailure(
    'Il tuo profilo non è completo: aggiungi il nome dal tuo profilo e '
    'riprova.',
  ),
  'account_invalid' => const CheckInPreconditionFailure(
    'Il tuo account non è ancora pronto. Esci e rientra, poi riprova.',
  ),
  'friend_missing' => const CheckInPreconditionFailure(
    'Uno degli amici taggati non è più tra i tuoi amici. Rimuovilo dal tag '
    'e riprova.',
  ),
  'already_deleted' => const CheckInPreconditionFailure(
    'Questo check-in è stato eliminato e non può essere ripubblicato. '
    'Creane uno nuovo.',
  ),
  'foreign_check_in' => const CheckInPermissionFailure(),
  'foreign_photo' => const CheckInPermissionFailure(),
  'limit_reached' => const CheckInPreconditionFailure(
    'Hai raggiunto il limite di punti registrabili. Contatta l’assistenza.',
  ),
  _ => null,
};
