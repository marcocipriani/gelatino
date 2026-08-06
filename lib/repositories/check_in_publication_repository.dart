import 'dart:async';
import 'dart:convert';

import 'check_in_draft_repository.dart';
import 'check_in_repository.dart';

enum CheckInPublicationPhase { calling, published, failed }

enum CheckInPublicationFailureReason {
  authentication,
  permission,
  validation,
  mediaMissing,
  precondition,
}

final class CheckInPublicationMarker {
  const CheckInPublicationMarker.calling(this.draftId)
    : phase = CheckInPublicationPhase.calling,
      result = null,
      failure = null;

  const CheckInPublicationMarker.published(this.draftId, this.result)
    : phase = CheckInPublicationPhase.published,
      failure = null;

  const CheckInPublicationMarker.failed(this.draftId, this.failure)
    : phase = CheckInPublicationPhase.failed,
      result = null;

  final String draftId;
  final CheckInPublicationPhase phase;
  final PublishCheckInResult? result;
  final CheckInPublicationFailureReason? failure;

  Map<String, Object?> toJson() {
    _validate();
    return switch (phase) {
      CheckInPublicationPhase.calling => <String, Object?>{
        'draft_id': draftId,
        'phase': 'calling',
      },
      CheckInPublicationPhase.published => <String, Object?>{
        'draft_id': draftId,
        'phase': 'published',
        'result': <String, Object?>{
          'check_in_id': result!.checkInId,
          'status': result!.status.name,
        },
      },
      CheckInPublicationPhase.failed => <String, Object?>{
        'draft_id': draftId,
        'phase': 'failed',
        'failure': _failureName(failure!),
      },
    };
  }

  factory CheckInPublicationMarker.fromJson(Map<String, dynamic> json) {
    final phase = json['phase'];
    if (phase == 'calling') {
      _requireExactKeys(json, const <String>{'draft_id', 'phase'});
      final marker = CheckInPublicationMarker.calling(
        _requiredString(json, 'draft_id'),
      );
      marker._validate();
      return marker;
    }
    if (phase == 'published') {
      _requireExactKeys(json, const <String>{'draft_id', 'phase', 'result'});
      final resultJson = json['result'];
      if (resultJson is! Map<String, dynamic>) {
        throw const FormatException('result: expected object');
      }
      _requireExactKeys(resultJson, const <String>{'check_in_id', 'status'});
      final status = switch (resultJson['status']) {
        'created' => PublishCheckInStatus.created,
        'existing' => PublishCheckInStatus.existing,
        _ => throw const FormatException('result.status: invalid'),
      };
      final draftId = _requiredString(json, 'draft_id');
      final marker = CheckInPublicationMarker.published(
        draftId,
        PublishCheckInResult(
          _requiredString(resultJson, 'check_in_id'),
          status,
        ),
      );
      marker._validate();
      return marker;
    }
    if (phase == 'failed') {
      _requireExactKeys(json, const <String>{'draft_id', 'phase', 'failure'});
      final failure = switch (json['failure']) {
        'authentication' => CheckInPublicationFailureReason.authentication,
        'permission' => CheckInPublicationFailureReason.permission,
        'validation' => CheckInPublicationFailureReason.validation,
        'media_missing' => CheckInPublicationFailureReason.mediaMissing,
        'precondition' => CheckInPublicationFailureReason.precondition,
        _ => throw const FormatException('failure: invalid'),
      };
      final marker = CheckInPublicationMarker.failed(
        _requiredString(json, 'draft_id'),
        failure,
      );
      marker._validate();
      return marker;
    }
    throw const FormatException('phase: invalid');
  }

  void _validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(draftId)) {
      throw const FormatException('draft_id: invalid');
    }
    switch (phase) {
      case CheckInPublicationPhase.calling:
        if (result != null || failure != null) {
          throw const FormatException('calling marker: unexpected payload');
        }
      case CheckInPublicationPhase.published:
        if (result == null || result!.checkInId != draftId || failure != null) {
          throw const FormatException('published marker: invalid result');
        }
      case CheckInPublicationPhase.failed:
        if (result != null || failure == null) {
          throw const FormatException('failed marker: invalid failure');
        }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CheckInPublicationMarker &&
      other.draftId == draftId &&
      other.phase == phase &&
      other.result == result &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(draftId, phase, result, failure);
}

String _failureName(CheckInPublicationFailureReason failure) =>
    switch (failure) {
      CheckInPublicationFailureReason.authentication => 'authentication',
      CheckInPublicationFailureReason.permission => 'permission',
      CheckInPublicationFailureReason.validation => 'validation',
      CheckInPublicationFailureReason.mediaMissing => 'media_missing',
      CheckInPublicationFailureReason.precondition => 'precondition',
    };

abstract interface class CheckInPublicationRepository {
  Future<CheckInPublicationMarker?> load(String uid);

  Future<void> save(String uid, CheckInPublicationMarker marker);

  Future<void> clear(String uid);
}

final class PersistentCheckInPublicationRepository
    implements CheckInPublicationRepository {
  PersistentCheckInPublicationRepository(this._preferences);

  final DraftPreferences _preferences;
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  @override
  Future<CheckInPublicationMarker?> load(String uid) async {
    _requireUid(uid);
    final pending = _tails[uid];
    if (pending != null) await pending;
    final encoded = _preferences.getString(_key(uid));
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('publication marker: expected JSON object');
    }
    return CheckInPublicationMarker.fromJson(value);
  }

  @override
  Future<void> save(String uid, CheckInPublicationMarker marker) {
    _requireUid(uid);
    final encoded = jsonEncode(marker.toJson());
    return _enqueue(uid, () async {
      if (!await _preferences.setString(_key(uid), encoded)) {
        throw StateError('Impossibile salvare lo stato di pubblicazione.');
      }
    });
  }

  @override
  Future<void> clear(String uid) {
    _requireUid(uid);
    return _enqueue(uid, () async {
      if (!await _preferences.remove(_key(uid))) {
        throw StateError('Impossibile eliminare lo stato di pubblicazione.');
      }
    });
  }

  Future<void> _enqueue(String uid, Future<void> Function() action) {
    final previous = _tails[uid];
    final operation = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // A later cleanup must be able to recover from a failed marker write.
        }
      }
      await action();
    }();
    _tails[uid] = operation;
    return operation;
  }

  String _key(String uid) => 'check_in_publication_v2_$uid';
}

void _requireUid(String uid) {
  if (uid.isEmpty || uid.length > 128 || uid.contains('/')) {
    throw const FormatException('uid: invalid');
  }
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const FormatException('publication marker: invalid fields');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key: expected string');
  return value;
}
