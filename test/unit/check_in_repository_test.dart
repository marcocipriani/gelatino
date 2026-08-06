import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in_draft.dart';
import 'package:gelatino/repositories/check_in_repository.dart';

void main() {
  const id = 'ABCDEFGHIJKLMNOPQRST';
  final draft = CheckInDraft(
    id: id,
    currentStep: 4,
    localPhotoName: 'gelato.png',
    stagingObjectPath: 'staging/alice/$id.jpg',
    placeId: 'place-1',
    pendingPlace: null,
    gelatoTypeId: 'cono',
    flavorIds: const ['pistacchio', 'nocciola'],
    rating: 5,
    reviewText: 'Ottimo',
    taggedUserIds: const ['bob'],
    updatedAt: DateTime.utc(2026, 7, 15),
  );

  test(
    'publish sends the exact callable contract and validates result',
    () async {
      final source = _RecordingCallableSource()
        ..result = {'checkInId': id, 'status': 'created'};
      final repository = CallableCheckInRepository(source);

      final result = await repository.publish(draft);

      expect(source.calls.single.name, 'createCheckIn');
      expect(source.calls.single.payload, {
        'checkInId': id,
        'placeId': 'place-1',
        'gelatoTypeId': 'cono',
        'flavorIds': ['pistacchio', 'nocciola'],
        'rating': 5,
        'reviewText': 'Ottimo',
        'taggedUserIds': ['bob'],
        'stagingObjectPath': 'staging/alice/$id.jpg',
      });
      expect(
        result,
        const PublishCheckInResult(id, PublishCheckInStatus.created),
      );
    },
  );

  test('existing is a successful idempotent result', () async {
    final source = _RecordingCallableSource()
      ..result = {'checkInId': id, 'status': 'existing'};

    expect(
      await CallableCheckInRepository(source).publish(draft),
      const PublishCheckInResult(id, PublishCheckInStatus.existing),
    );
  });

  test('delete sends only the check-in ID', () async {
    final source = _RecordingCallableSource()..result = null;

    await CallableCheckInRepository(source).delete(id);

    expect(source.calls.single.name, 'deleteCheckIn');
    expect(source.calls.single.payload, {'checkInId': id});
  });

  test('rejects incomplete drafts before invoking the callable', () async {
    final source = _RecordingCallableSource();
    final incomplete = CheckInDraft(
      id: id,
      currentStep: 4,
      localPhotoName: null,
      stagingObjectPath: null,
      placeId: null,
      pendingPlace: null,
      gelatoTypeId: null,
      flavorIds: const [],
      rating: null,
      reviewText: '',
      taggedUserIds: const [],
      updatedAt: DateTime.utc(2026, 7, 15),
    );

    await expectLater(
      CallableCheckInRepository(source).publish(incomplete),
      throwsA(isA<CheckInValidationFailure>()),
    );
    expect(source.calls, isEmpty);
  });

  test('rejects malformed or mismatched callable results', () async {
    final source = _RecordingCallableSource()
      ..result = {'checkInId': 'ZYXWVUTSRQPONMLKJIHG', 'status': 'created'};

    await expectLater(
      CallableCheckInRepository(source).publish(draft),
      throwsA(isA<CheckInProtocolFailure>()),
    );
  });

  test('maps remote failures into typed Italian-facing failures', () async {
    final cases = <String, Type>{
      'unauthenticated': CheckInAuthenticationFailure,
      'permission-denied': CheckInPermissionFailure,
      'invalid-argument': CheckInValidationFailure,
      'not-found': CheckInMediaMissingFailure,
      'failed-precondition': CheckInPreconditionFailure,
      'unavailable': CheckInRetryableFailure,
      'deadline-exceeded': CheckInRetryableFailure,
      'internal': CheckInRetryableFailure,
      'unknown-code': CheckInRemoteFailure,
    };

    for (final entry in cases.entries) {
      final source = _RecordingCallableSource()
        ..error = CheckInCallableException(entry.key);
      await expectLater(
        CallableCheckInRepository(source).publish(draft),
        throwsA(
          isA<CheckInFailure>()
              .having((e) => e.runtimeType, 'type', entry.value)
              .having((e) => e.toString(), 'message', isNotEmpty),
        ),
        reason: entry.key,
      );
    }
  });

  test('backend reasons win over the coarse status code', () async {
    // Every reason the callable can send must produce its own message, so no
    // two causes can show the same unhelpful text.
    const reasons = <String, String>{
      'photo_missing': 'not-found',
      'photo_invalid': 'failed-precondition',
      'place_missing': 'not-found',
      'gelato_type_missing': 'not-found',
      'flavor_missing': 'not-found',
      'catalog_invalid': 'failed-precondition',
      'profile_missing': 'not-found',
      'account_invalid': 'failed-precondition',
      'friend_missing': 'failed-precondition',
      'already_deleted': 'failed-precondition',
      'limit_reached': 'failed-precondition',
    };
    final messages = <String>{};

    for (final entry in reasons.entries) {
      final source = _RecordingCallableSource()
        ..error = CheckInCallableException(entry.value, entry.key);
      late final CheckInFailure failure;
      try {
        await CallableCheckInRepository(source).publish(draft);
        fail('publish should have failed for ${entry.key}');
      } on CheckInFailure catch (error) {
        failure = error;
      }
      expect(failure.message, isNotEmpty, reason: entry.key);
      expect(
        messages.add(failure.message),
        isTrue,
        reason: '${entry.key} reuses another reason message',
      );
    }

    final unknown = _RecordingCallableSource()
      ..error = const CheckInCallableException('failed-precondition', 'nope');
    await expectLater(
      CallableCheckInRepository(unknown).publish(draft),
      throwsA(isA<CheckInPreconditionFailure>()),
    );
  });
}

final class _RecordingCallableSource implements CheckInCallableDataSource {
  final List<({String name, Map<String, Object?> payload})> calls = [];
  Object? result;
  Object? error;

  @override
  Future<Object?> call(String name, Map<String, Object?> payload) async {
    calls.add((name: name, payload: payload));
    if (error case final error?) throw error;
    return result;
  }
}
