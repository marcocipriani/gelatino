import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/check_in_draft.dart';

void main() {
  const checkInId = 'ABCDEFGHIJKLMNOPQRST';
  final now = DateTime.utc(2026, 7, 15, 8, 30);

  test('new draft generates one valid ID and starts at step zero', () {
    var calls = 0;
    final draft = CheckInDraft.create(
      idGenerator: () {
        calls++;
        return checkInId;
      },
      now: () => now,
    );

    expect(calls, 1);
    expect(draft.id, checkInId);
    expect(draft.currentStep, 0);
    expect(draft.updatedAt, now);
  });

  test('complete metadata survives an exact JSON round trip', () {
    final draft = CheckInDraft(
      id: checkInId,
      currentStep: 4,
      localPhotoName: 'gelato.png',
      stagingObjectPath: 'staging/alice/$checkInId.jpg',
      placeId: 'place-1',
      pendingPlace: null,
      gelatoTypeId: 'cono',
      flavorIds: const ['pistacchio', 'nocciola'],
      rating: 5,
      reviewText: 'Molto buono',
      taggedUserIds: const ['bob', 'carol'],
      updatedAt: now,
    );

    final restored = CheckInDraft.fromJson(draft.toJson());

    expect(restored, draft);
    expect(restored.toJson().keys.toSet(), {
      'id',
      'current_step',
      'local_photo_name',
      'staging_object_path',
      'place_id',
      'pending_place',
      'gelato_type_id',
      'flavor_ids',
      'rating',
      'review_text',
      'tagged_user_ids',
      'updated_at',
    });
  });

  test('pending place with explicit map coordinates round trips', () {
    final pending = PendingPlaceDraft(
      name: 'Gelateria Nuova',
      address: 'Via Milano 1',
      latitude: 45.46,
      longitude: 9.19,
    );
    final draft = CheckInDraft(
      id: checkInId,
      currentStep: 1,
      localPhotoName: null,
      stagingObjectPath: null,
      placeId: null,
      pendingPlace: pending,
      gelatoTypeId: null,
      flavorIds: const [],
      rating: null,
      reviewText: '',
      taggedUserIds: const [],
      updatedAt: now,
    );

    expect(CheckInDraft.fromJson(draft.toJson()).pendingPlace, pending);
  });

  test('rejects malformed IDs, bounds, duplicates and conflicting places', () {
    CheckInDraft build({
      String id = checkInId,
      int step = 0,
      String? placeId,
      PendingPlaceDraft? pendingPlace,
      List<String> flavors = const [],
      int? rating,
      List<String> tagged = const [],
    }) => CheckInDraft(
      id: id,
      currentStep: step,
      localPhotoName: null,
      stagingObjectPath: null,
      placeId: placeId,
      pendingPlace: pendingPlace,
      gelatoTypeId: null,
      flavorIds: flavors,
      rating: rating,
      reviewText: '',
      taggedUserIds: tagged,
      updatedAt: now,
    );

    expect(() => build(id: 'short'), throwsFormatException);
    expect(() => build(step: 5), throwsFormatException);
    expect(() => build(rating: 0), throwsFormatException);
    expect(
      () => build(flavors: const ['a', 'b', 'c', 'd', 'e']),
      throwsFormatException,
    );
    expect(
      () => build(flavors: const ['pistacchio', 'pistacchio']),
      throwsFormatException,
    );
    expect(() => build(tagged: const ['bob', 'bob']), throwsFormatException);
    expect(
      () => build(
        placeId: 'place-1',
        pendingPlace: PendingPlaceDraft(name: 'Nuova', address: 'Via 1'),
      ),
      throwsFormatException,
    );
  });

  test('rejects partial or invalid pending coordinates', () {
    expect(
      () => PendingPlaceDraft(name: 'Nuova', address: 'Via 1', latitude: 45),
      throwsFormatException,
    );
    expect(
      () => PendingPlaceDraft(
        name: 'Nuova',
        address: 'Via 1',
        latitude: 91,
        longitude: 9,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed JSON and public staging URLs', () {
    final json = CheckInDraft(
      id: checkInId,
      currentStep: 0,
      localPhotoName: null,
      stagingObjectPath: null,
      placeId: null,
      pendingPlace: null,
      gelatoTypeId: null,
      flavorIds: const [],
      rating: null,
      reviewText: '',
      taggedUserIds: const [],
      updatedAt: now,
    ).toJson();

    expect(
      () => CheckInDraft.fromJson({...json, 'unexpected': true}),
      throwsFormatException,
    );
    expect(
      () => CheckInDraft.fromJson({
        ...json,
        'staging_object_path': 'https://example.test/photo.jpg',
      }),
      throwsFormatException,
    );
    for (final path in [
      'staging/../$checkInId.jpg',
      'staging/alice\\bad/$checkInId.jpg',
      'staging/alice/$checkInId.jpg?token=x',
    ]) {
      expect(
        () => CheckInDraft.fromJson({...json, 'staging_object_path': path}),
        throwsFormatException,
        reason: path,
      );
    }
  });

  test('consumed_at survives a round trip and stays bounded', () {
    final base = CheckInDraft.create(
      idGenerator: () => checkInId,
      now: () => DateTime.now(),
    );
    expect(base.consumedAt, isNull);
    // Drafts persisted before backdating shipped have no key at all.
    expect(base.toJson().containsKey('consumed_at'), isFalse);
    expect(CheckInDraft.fromJson(base.toJson()).consumedAt, isNull);

    final consumed = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final backdated = base.copyWith(consumedAt: consumed);
    expect(CheckInDraft.fromJson(backdated.toJson()).consumedAt, consumed);
    // The sentinel keeps `copyWith` from silently dropping it.
    expect(backdated.copyWith(rating: 4).consumedAt, consumed);
    expect(backdated.copyWith(consumedAt: null).consumedAt, isNull);

    expect(
      () => base.copyWith(
        consumedAt: DateTime.now().add(const Duration(days: 1)),
      ),
      throwsFormatException,
    );
    expect(
      () => base.copyWith(
        consumedAt: DateTime.now().subtract(const Duration(days: 6 * 365)),
      ),
      throwsFormatException,
    );
  });
}
