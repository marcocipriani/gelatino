import type {Storage} from 'firebase-admin/storage';
import {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Firestore,
  Timestamp,
} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import type {CreateCheckInInput} from '../domain/contracts';
import {pairId, permanentPhotoPath} from '../domain/ids';
import {
  CHECK_IN_BASE_POINTS,
  MIN_REPEAT_POINTS,
  SHARED_CHECK_IN_BASE_POINTS,
  TAGGED_FRIEND_AFFINITY,
  monthKey,
  pointsForParticipation,
} from '../domain/scoring';
import {validateCreateCheckInInput} from '../domain/validation';

type StorageBucket = ReturnType<Storage['bucket']>;

export type CreateCheckInResult = {
  checkInId: string;
  status: 'created' | 'existing';
};

export type DeleteCheckInResult = {
  checkInId: string;
  status: 'deleted' | 'already-deleted';
};

type AwardedPoints = {uid: string; points: number};
type VisitCountDelta = {uid: string; delta: number};
type FriendshipAffinityDelta = {friendship_id: string; delta: number};

type Accounting = {
  authorUid: string;
  placeId: string;
  awardedPoints: AwardedPoints[];
  visitCountDeltas: VisitCountDelta[];
  friendshipAffinityDeltas: FriendshipAffinityDelta[];
};

const MAX_PHOTO_SIZE = 5 * 1024 * 1024;
const PATH_SEGMENT_PATTERN = /^[^/\u0000-\u001f\u007f]{1,128}$/u;

const HEX_COLOR_PATTERN = /^#[0-9A-Fa-f]{6}$/;
const STAGING_COLOR_METADATA_KEY = 'dominant_color';

/// Stable machine-readable causes the app maps to actionable messages.
/// Never rename one without updating `_messageForReason` in
/// lib/repositories/check_in_repository.dart.
export type CheckInFailureReason =
  | 'photo_missing'
  | 'photo_invalid'
  | 'place_missing'
  | 'gelato_type_missing'
  | 'flavor_missing'
  | 'profile_missing'
  | 'catalog_invalid'
  | 'friend_missing'
  | 'already_deleted'
  | 'foreign_check_in'
  | 'foreign_photo'
  | 'account_invalid'
  | 'limit_reached'
  | 'internal';

function failed(
  message: string,
  reason: CheckInFailureReason = 'internal',
): never {
  throw new HttpsError('failed-precondition', message, {reason});
}

function notFound(message: string, reason: CheckInFailureReason): never {
  throw new HttpsError('not-found', message, {reason});
}

function denied(message: string, reason: CheckInFailureReason): never {
  throw new HttpsError('permission-denied', message, {reason});
}

function requirePathSegment(value: string, label: string): void {
  if (!PATH_SEGMENT_PATTERN.test(value)) {
    throw new HttpsError('invalid-argument', `${label} is invalid`);
  }
}

function createInput(value: unknown, callerUid: string): CreateCheckInInput {
  try {
    const input = validateCreateCheckInInput(value, callerUid);
    requirePathSegment(input.placeId, 'placeId');
    requirePathSegment(input.gelatoTypeId, 'gelatoTypeId');
    input.flavorIds.forEach((id) => requirePathSegment(id, 'flavorIds'));
    input.taggedUserIds.forEach((id) =>
      requirePathSegment(id, 'taggedUserIds'),
    );
    return input;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const message = error instanceof Error ? error.message : 'Input is invalid';
    if (
      message ===
        'stagingObjectPath: must match the caller and check-in'
    ) {
      denied(message, 'foreign_photo');
    }
    throw new HttpsError('invalid-argument', message);
  }
}

function dataOf(
  snapshot: DocumentSnapshot,
  missingMessage: string,
  reason: CheckInFailureReason = 'internal',
): DocumentData {
  if (!snapshot.exists) notFound(missingMessage, reason);
  return snapshot.data()!;
}

function stringField(
  data: DocumentData,
  field: string,
  label: string,
  reason: CheckInFailureReason = 'internal',
): string {
  const value = data[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    failed(`${label}.${field} is invalid`, reason);
  }
  return value;
}

/// A string the product does not force the user to fill in yet. Blocking a
/// publication on it locks the account out of the whole feature.
// ponytail: no UI writes `username` today, so it is always ''. Tighten this to
// stringField() once onboarding requires a username.
function optionalStringField(
  data: DocumentData,
  field: string,
  label: string,
  reason: CheckInFailureReason = 'internal',
): string {
  const value = data[field];
  if (value === undefined || value === null) return '';
  if (typeof value !== 'string') failed(`${label}.${field} is invalid`, reason);
  return value;
}

function nullableStringField(
  data: DocumentData,
  field: string,
  label: string,
  reason: CheckInFailureReason = 'internal',
): string | null {
  const value = data[field];
  if (value !== null && typeof value !== 'string') {
    failed(`${label}.${field} is invalid`, reason);
  }
  return value;
}

function nullableHexColorField(
  data: DocumentData,
  field: string,
  label: string,
  reason: CheckInFailureReason = 'internal',
): string | null {
  const value = data[field];
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string' || !HEX_COLOR_PATTERN.test(value)) {
    failed(`${label}.${field} is invalid`, reason);
  }
  return value;
}

function nonNegativeInteger(
  value: unknown,
  label: string,
  reason: CheckInFailureReason = 'internal',
): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    failed(`${label} is invalid`, reason);
  }
  return value as number;
}

function positiveInteger(value: unknown, label: string): number {
  const number = nonNegativeInteger(value, label);
  if (number === 0) failed(`${label} is invalid`);
  return number;
}

function safeAdd(left: number, right: number, label: string): number {
  const result = left + right;
  if (!Number.isSafeInteger(result) || result < 0) {
    failed(`${label} would exceed the safe integer range`, 'limit_reached');
  }
  return result;
}

function snapshotMap(
  snapshots: DocumentSnapshot[],
): Map<string, DocumentSnapshot> {
  return new Map(snapshots.map((snapshot) => [snapshot.ref.path, snapshot]));
}

function mappedSnapshot(
  snapshots: Map<string, DocumentSnapshot>,
  reference: DocumentReference,
): DocumentSnapshot {
  const snapshot = snapshots.get(reference.path);
  if (!snapshot) throw new Error(`Snapshot missing for ${reference.path}`);
  return snapshot;
}

function validatePrivateUser(snapshot: DocumentSnapshot, uid: string): void {
  const data = dataOf(snapshot, `User ${uid} not found`, 'account_invalid');
  nonNegativeInteger(data.points, `users/${uid}.points`, 'account_invalid');
}

function validateFriendship(
  snapshot: DocumentSnapshot,
  callerUid: string,
  taggedUid: string,
  requireAccepted: boolean,
): void {
  if (!snapshot.exists) {
    failed('Tagged user is not an accepted friend', 'friend_missing');
  }
  const data = snapshot.data()!;
  if (
    !Array.isArray(data.member_uids) ||
    !data.member_uids.includes(callerUid) ||
    !data.member_uids.includes(taggedUid) ||
    (requireAccepted && data.state !== 'accepted')
  ) {
    failed('Tagged user is not an accepted friend', 'friend_missing');
  }
  nonNegativeInteger(data.affinity_score, `${snapshot.ref.path}.affinity_score`);
}

function storageObjectMissing(error: unknown): boolean {
  const code = (error as {code?: unknown}).code;
  return code === 404 || code === '404' || code === 'storage/object-not-found';
}

function mediaNotFound(error: unknown): boolean {
  return storageObjectMissing(error) ||
    (error instanceof HttpsError && error.code === 'not-found');
}

function validateTombstone(snapshot: DocumentSnapshot): string | null {
  if (!snapshot.exists) return null;
  const ownerUid = snapshot.get('owner_uid');
  if (
    typeof ownerUid !== 'string' ||
    !PATH_SEGMENT_PATTERN.test(ownerUid) ||
    snapshot.get('schema_version') !== 1 ||
    !(snapshot.get('deleted_at') instanceof Timestamp)
  ) {
    failed('Check-in tombstone is invalid');
  }
  return ownerUid;
}

async function resolveMissingMediaRace(
  db: Firestore,
  canonicalRef: DocumentReference,
  tombstoneRef: DocumentReference,
  callerUid: string,
  checkInId: string,
): Promise<CreateCheckInResult> {
  const raceSnapshots = await db.getAll(canonicalRef, tombstoneRef);
  const canonical = raceSnapshots[0]!;
  const tombstone = raceSnapshots[1]!;
  if (validateTombstone(tombstone) !== null) {
    failed('Check-in ID has already been deleted', 'already_deleted');
  }
  if (!canonical.exists) {
    notFound('Staging photo not found', 'photo_missing');
  }
  if (canonical.get('user_id') !== callerUid) {
    denied('Check-in belongs to another user', 'foreign_check_in');
  }
  return {checkInId, status: 'existing'};
}

async function validateStagingPhoto(
  bucket: StorageBucket,
  path: string,
) {
  const file = bucket.file(path);
  let metadata;
  try {
    [metadata] = await file.getMetadata();
  } catch (error) {
    if (storageObjectMissing(error)) {
      notFound('Staging photo not found', 'photo_missing');
    }
    throw error;
  }

  const size = Number(metadata.size);
  if (
    metadata.contentType !== 'image/jpeg' ||
    !Number.isFinite(size) ||
    size < 0 ||
    size > MAX_PHOTO_SIZE
  ) {
    failed('Staging photo metadata is invalid', 'photo_invalid');
  }
  // Set by the client from the pixels it encoded; purely cosmetic, so a
  // missing or malformed value is dropped instead of failing the publish.
  const color = metadata.metadata?.[STAGING_COLOR_METADATA_KEY];
  const photoColor =
    typeof color === 'string' && HEX_COLOR_PATTERN.test(color)
      ? color.toUpperCase()
      : undefined;
  return {file, photoColor};
}

export async function publishCheckIn(
  db: Firestore,
  bucket: StorageBucket,
  callerUid: string,
  value: unknown,
): Promise<CreateCheckInResult> {
  const input = createInput(value, callerUid);
  const canonicalRef = db.doc(`check_ins/${input.checkInId}`);
  const accountingRef = db.doc(`check_in_accounting/${input.checkInId}`);
  const tombstoneRef = db.doc(`check_in_tombstones/${input.checkInId}`);
  const existingSnapshots = await db.getAll(canonicalRef, tombstoneRef);
  const existing = existingSnapshots[0]!;
  const existingTombstone = existingSnapshots[1]!;
  if (validateTombstone(existingTombstone) !== null) {
    failed('Check-in ID has already been deleted', 'already_deleted');
  }
  if (existing.exists) {
    if (existing.get('user_id') !== callerUid) {
      denied('Check-in belongs to another user', 'foreign_check_in');
    }
    return {checkInId: input.checkInId, status: 'existing'};
  }

  const placeRef = db.doc(`places/${input.placeId}`);
  const gelatoTypeRef = db.doc(`gelato_types/${input.gelatoTypeId}`);
  const flavorRefs = input.flavorIds.map((id) => db.doc(`flavors/${id}`));
  const participantUids = [callerUid, ...input.taggedUserIds];
  const userRefs = participantUids.map((uid) => db.doc(`users/${uid}`));
  const profileRefs = participantUids.map((uid) =>
    db.doc(`public_profiles/${uid}`),
  );
  const friendshipIds = input.taggedUserIds.map((uid) => pairId(callerUid, uid));
  const friendshipRefs = friendshipIds.map((id) =>
    db.doc(`friendships/${id}`),
  );
  const accessRefs = input.taggedUserIds.flatMap((uid) => [
    db.doc(`friend_access/${callerUid}/members/${uid}`),
    db.doc(`friend_access/${uid}/members/${callerUid}`),
  ]);

  const preflightSnapshots = await db.getAll(
    placeRef,
    gelatoTypeRef,
    ...flavorRefs,
    ...userRefs,
    ...profileRefs,
    ...accessRefs,
    ...friendshipRefs,
  );
  const preflight = snapshotMap(preflightSnapshots);
  const placeData = dataOf(
    mappedSnapshot(preflight, placeRef),
    'Place not found',
    'place_missing',
  );
  const placeSnapshot = {
    name: stringField(placeData, 'name', placeRef.path, 'catalog_invalid'),
    address: stringField(
      placeData,
      'address',
      placeRef.path,
      'catalog_invalid',
    ),
  };
  const typeData = dataOf(
    mappedSnapshot(preflight, gelatoTypeRef),
    'Gelato type not found',
    'gelato_type_missing',
  );
  const gelatoType = {
    id: input.gelatoTypeId,
    name: stringField(typeData, 'name', gelatoTypeRef.path, 'catalog_invalid'),
  };
  const flavors = flavorRefs.map((reference, index) => {
    const data = dataOf(
      mappedSnapshot(preflight, reference),
      `Flavor ${input.flavorIds[index]} not found`,
      'flavor_missing',
    );
    return {
      id: input.flavorIds[index]!,
      name: stringField(data, 'name', reference.path, 'catalog_invalid'),
      color_hex: nullableHexColorField(
        data,
        'color_hex',
        reference.path,
        'catalog_invalid',
      ),
    };
  });

  userRefs.forEach((reference, index) =>
    validatePrivateUser(
      mappedSnapshot(preflight, reference),
      participantUids[index]!,
    ),
  );
  const profiles = profileRefs.map((reference, index) => {
    const data = dataOf(
      mappedSnapshot(preflight, reference),
      `Public profile ${participantUids[index]} not found`,
      'profile_missing',
    );
    return {
      display_name: stringField(
        data,
        'display_name',
        reference.path,
        'profile_missing',
      ),
      username: optionalStringField(
        data,
        'username',
        reference.path,
        'profile_missing',
      ),
      avatar_path: nullableStringField(
        data,
        'avatar_path',
        reference.path,
        'profile_missing',
      ),
    };
  });

  input.taggedUserIds.forEach((taggedUid, index) => {
    const friendshipId = friendshipIds[index]!;
    const forward = mappedSnapshot(preflight, accessRefs[index * 2]!);
    const reciprocal = mappedSnapshot(preflight, accessRefs[index * 2 + 1]!);
    if (
      !forward.exists ||
      !reciprocal.exists ||
      forward.get('friendship_id') !== friendshipId ||
      reciprocal.get('friendship_id') !== friendshipId
    ) {
      failed('Tagged user is not an accepted friend', 'friend_missing');
    }
    validateFriendship(
      mappedSnapshot(preflight, friendshipRefs[index]!),
      callerUid,
      taggedUid,
      true,
    );
  });

  let stagingFile;
  let photoColor: string | undefined;
  try {
    ({file: stagingFile, photoColor} = await validateStagingPhoto(
      bucket,
      input.stagingObjectPath,
    ));
  } catch (error) {
    if (mediaNotFound(error)) {
      return resolveMissingMediaRace(
        db,
        canonicalRef,
        tombstoneRef,
        callerUid,
        input.checkInId,
      );
    }
    throw error;
  }
  const permanentPath = permanentPhotoPath(callerUid, input.checkInId, 1);
  try {
    await stagingFile.copy(bucket.file(permanentPath), {
      contentType: 'image/jpeg',
      // The staging object carries `private, no-store` because it is a scratch
      // upload; GCS copies source metadata unless overridden, which made every
      // published photo uncacheable and re-downloaded on each feed render.
      // `permanentPhotoPath` embeds a version, so the content is immutable.
      cacheControl: 'private, max-age=31536000, immutable',
      metadata: {firebaseStorageDownloadTokens: null},
    });
  } catch (error) {
    if (mediaNotFound(error)) {
      return resolveMissingMediaRace(
        db,
        canonicalRef,
        tombstoneRef,
        callerUid,
        input.checkInId,
      );
    }
    throw error;
  }

  const visitRefs = participantUids.map((uid) =>
    db.doc(`users/${uid}/place_visit_stats/${input.placeId}`),
  );
  const transactionRefs = [
    canonicalRef,
    accountingRef,
    tombstoneRef,
    ...userRefs,
    ...visitRefs,
    ...friendshipRefs,
  ];

  const result = await db.runTransaction(async (transaction) => {
    const snapshots = snapshotMap(
      await transaction.getAll(...transactionRefs),
    );
    const canonical = mappedSnapshot(snapshots, canonicalRef);
    const tombstone = mappedSnapshot(snapshots, tombstoneRef);
    if (validateTombstone(tombstone) !== null) {
      failed('Check-in ID has already been deleted', 'already_deleted');
    }
    if (canonical.exists) {
      if (canonical.get('user_id') !== callerUid) {
        denied('Check-in belongs to another user', 'foreign_check_in');
      }
      return {
        checkInId: input.checkInId,
        status: 'existing' as const,
      };
    }
    if (mappedSnapshot(snapshots, accountingRef).exists) {
      failed('Check-in accounting pair is corrupt');
    }

    const awardedPoints: AwardedPoints[] = participantUids.map(
      (uid, index) => {
        const userSnapshot = mappedSnapshot(snapshots, userRefs[index]!);
        validatePrivateUser(userSnapshot, uid);
        const visitSnapshot = mappedSnapshot(snapshots, visitRefs[index]!);
        const priorVisits = visitSnapshot.exists
          ? nonNegativeInteger(
            visitSnapshot.get('count'),
            `${visitSnapshot.ref.path}.count`,
          )
          : 0;
        const base =
          index === 0 && input.taggedUserIds.length === 0
            ? CHECK_IN_BASE_POINTS
            : SHARED_CHECK_IN_BASE_POINTS;
        return {
          uid,
          points: pointsForParticipation(base, priorVisits),
        };
      },
    );
    friendshipRefs.forEach((reference, index) =>
      validateFriendship(
        mappedSnapshot(snapshots, reference),
        callerUid,
        input.taggedUserIds[index]!,
        true,
      ),
    );

    const timestamp = FieldValue.serverTimestamp();
    transaction.create(canonicalRef, {
      user_id: callerUid,
      user_snapshot: profiles[0],
      place_id: input.placeId,
      place_snapshot: placeSnapshot,
      gelato_type: gelatoType,
      flavors,
      rating: input.rating,
      review_text: input.reviewText,
      tagged_user_ids: input.taggedUserIds,
      photo_storage_path: permanentPath,
      ...(photoColor === undefined ? {} : {photo_color: photoColor}),
      created_at: timestamp,
      // When the gelato was eaten, as opposed to when the row was written.
      // `created_at` stays server-owned because it is the feed cursor; this is
      // the one the UI shows. Omitted by the client means the two coincide.
      consumed_at: input.consumedAtMs === undefined
        ? timestamp
        : Timestamp.fromMillis(input.consumedAtMs),
      updated_at: timestamp,
      schema_version: 2,
    });
    const month = monthKey(new Date());
    awardedPoints.forEach(({points}, index) => {
      const userSnapshot = mappedSnapshot(snapshots, userRefs[index]!);
      const pointsLabel = `${userSnapshot.ref.path}.points`;
      const monthlyLabel = `${userSnapshot.ref.path}.monthly_points.${month}`;
      const monthlyRaw =
        (userSnapshot.get('monthly_points') as Record<string, unknown> | undefined)
          ?.[month] ?? 0;
      transaction.update(userRefs[index]!, {
        points: safeAdd(
          nonNegativeInteger(userSnapshot.get('points'), pointsLabel),
          points,
          pointsLabel,
        ),
        [`monthly_points.${month}`]: safeAdd(
          nonNegativeInteger(monthlyRaw, monthlyLabel),
          points,
          monthlyLabel,
        ),
      });
      const visitSnapshot = mappedSnapshot(snapshots, visitRefs[index]!);
      const count = visitSnapshot.exists
        ? nonNegativeInteger(
          visitSnapshot.get('count'),
          `${visitSnapshot.ref.path}.count`,
        )
        : 0;
      transaction.set(visitRefs[index]!, {
        count: safeAdd(count, 1, `${visitSnapshot.ref.path}.count`),
      });
    });
    friendshipRefs.forEach((reference) => {
      const friendship = mappedSnapshot(snapshots, reference);
      transaction.update(reference, {
        affinity_score: safeAdd(
          nonNegativeInteger(
            friendship.get('affinity_score'),
            `${friendship.ref.path}.affinity_score`,
          ),
          TAGGED_FRIEND_AFFINITY,
          `${friendship.ref.path}.affinity_score`,
        ),
      });
    });
    transaction.create(accountingRef, {
      author_uid: callerUid,
      place_id: input.placeId,
      awarded_points: awardedPoints,
      visit_count_deltas: participantUids.map((uid) => ({uid, delta: 1})),
      friendship_affinity_deltas: friendshipIds.map((friendshipId) => ({
        friendship_id: friendshipId,
        delta: TAGGED_FRIEND_AFFINITY,
      })),
      created_at: timestamp,
      schema_version: 1,
    });
    return {checkInId: input.checkInId, status: 'created' as const};
  });

  try {
    await stagingFile.delete({ignoreNotFound: true});
  } catch (error) {
    console.error('Failed to delete published staging photo', {
      path: input.stagingObjectPath,
      error,
    });
  }
  return result;
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    failed(`${label} is invalid`);
  }
  return value as Record<string, unknown>;
}

function exactEntry(
  value: unknown,
  keys: string[],
  label: string,
): Record<string, unknown> {
  const entry = record(value, label);
  const actual = Object.keys(entry).sort();
  const expected = [...keys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    failed(`${label} is invalid`);
  }
  return entry;
}

function accountingPathSegment(value: unknown, label: string): string {
  if (typeof value !== 'string' || !PATH_SEGMENT_PATTERN.test(value)) {
    failed(`${label} is invalid`);
  }
  return value;
}

function uniqueBy<T>(
  entries: T[],
  key: (entry: T) => string,
  label: string,
): void {
  if (new Set(entries.map(key)).size !== entries.length) {
    failed(`${label} contains duplicates`);
  }
}

function parseAccounting(snapshot: DocumentSnapshot): Accounting {
  const data = snapshot.data()!;
  if (data.schema_version !== 1 || !(data.created_at instanceof Timestamp)) {
    failed('Check-in accounting is invalid');
  }
  const authorUid = accountingPathSegment(data.author_uid, 'author_uid');
  const placeId = accountingPathSegment(data.place_id, 'place_id');
  if (
    !Array.isArray(data.awarded_points) ||
    !Array.isArray(data.visit_count_deltas) ||
    !Array.isArray(data.friendship_affinity_deltas)
  ) {
    failed('Check-in accounting deltas are invalid');
  }

  const awardedPoints = data.awarded_points.map(
    (value: unknown, index: number): AwardedPoints => {
      const entry = exactEntry(
        value,
        ['uid', 'points'],
        `awarded_points[${index}]`,
      );
      return {
        uid: accountingPathSegment(
          entry.uid,
          `awarded_points[${index}].uid`,
        ),
        points: positiveInteger(
          entry.points,
          `awarded_points[${index}].points`,
        ),
      };
    },
  );
  const visitCountDeltas = data.visit_count_deltas.map(
    (value: unknown, index: number): VisitCountDelta => {
      const entry = exactEntry(
        value,
        ['uid', 'delta'],
        `visit_count_deltas[${index}]`,
      );
      return {
        uid: accountingPathSegment(
          entry.uid,
          `visit_count_deltas[${index}].uid`,
        ),
        delta: positiveInteger(
          entry.delta,
          `visit_count_deltas[${index}].delta`,
        ),
      };
    },
  );
  const friendshipAffinityDeltas = data.friendship_affinity_deltas.map(
    (value: unknown, index: number): FriendshipAffinityDelta => {
      const entry = exactEntry(
        value,
        ['friendship_id', 'delta'],
        `friendship_affinity_deltas[${index}]`,
      );
      return {
        friendship_id: accountingPathSegment(
          entry.friendship_id,
          `friendship_affinity_deltas[${index}].friendship_id`,
        ),
        delta: positiveInteger(
          entry.delta,
          `friendship_affinity_deltas[${index}].delta`,
        ),
      };
    },
  );
  uniqueBy(awardedPoints, (entry) => entry.uid, 'awarded_points');
  uniqueBy(visitCountDeltas, (entry) => entry.uid, 'visit_count_deltas');
  uniqueBy(
    friendshipAffinityDeltas,
    (entry) => entry.friendship_id,
    'friendship_affinity_deltas',
  );
  if (
    awardedPoints.length === 0 ||
    !awardedPoints.some((entry) => entry.uid === authorUid) ||
    awardedPoints.length !== visitCountDeltas.length ||
    awardedPoints.some(
      (entry) => !visitCountDeltas.some((delta) => delta.uid === entry.uid),
    )
  ) {
    failed('Check-in accounting participants are invalid');
  }
  return {
    authorUid,
    placeId,
    awardedPoints,
    visitCountDeltas,
    friendshipAffinityDeltas,
  };
}

function sameMembers(actual: string[], expected: string[]): boolean {
  return actual.length === expected.length &&
    actual.every((value) => expected.includes(value));
}

function validateAccountingAgainstCanonical(
  canonical: DocumentSnapshot,
  accounting: Accounting,
): void {
  const rawTaggedUids = canonical.get('tagged_user_ids');
  if (!Array.isArray(rawTaggedUids)) {
    failed('Canonical check-in participants are invalid');
  }
  const taggedUids = rawTaggedUids.map((value, index) =>
    accountingPathSegment(value, `tagged_user_ids[${index}]`),
  );
  if (
    new Set(taggedUids).size !== taggedUids.length ||
    taggedUids.includes(accounting.authorUid)
  ) {
    failed('Canonical check-in participants are invalid');
  }
  const participantUids = [accounting.authorUid, ...taggedUids];
  const expectedFriendshipIds = taggedUids.map((uid) =>
    pairId(accounting.authorUid, uid),
  );
  const invalidAward = accounting.awardedPoints.some((entry) => {
    const base =
      entry.uid === accounting.authorUid && taggedUids.length === 0
        ? CHECK_IN_BASE_POINTS
        : SHARED_CHECK_IN_BASE_POINTS;
    return entry.points !== pointsForParticipation(base, 0) &&
      (entry.points < MIN_REPEAT_POINTS || entry.points >= base);
  });
  if (
    invalidAward ||
    !sameMembers(
      accounting.awardedPoints.map((entry) => entry.uid),
      participantUids,
    ) ||
    !sameMembers(
      accounting.visitCountDeltas.map((entry) => entry.uid),
      participantUids,
    ) ||
    accounting.visitCountDeltas.some((entry) => entry.delta !== 1) ||
    !sameMembers(
      accounting.friendshipAffinityDeltas.map(
        (entry) => entry.friendship_id,
      ),
      expectedFriendshipIds,
    ) ||
    accounting.friendshipAffinityDeltas.some(
      (entry) => entry.delta !== TAGGED_FRIEND_AFFINITY,
    )
  ) {
    failed('Check-in accounting does not match canonical participants');
  }
}

function ownerFrom(
  canonical: DocumentSnapshot,
  accounting: DocumentSnapshot,
): string | null {
  const canonicalOwner = canonical.exists
    ? canonical.get('user_id')
    : undefined;
  const accountingOwner = accounting.exists
    ? accounting.get('author_uid')
    : undefined;
  if (canonical.exists && typeof canonicalOwner !== 'string') {
    failed('Canonical check-in is invalid');
  }
  if (accounting.exists && typeof accountingOwner !== 'string') {
    failed('Check-in accounting is invalid');
  }
  if (
    typeof canonicalOwner === 'string' &&
    typeof accountingOwner === 'string' &&
    canonicalOwner !== accountingOwner
  ) {
    failed('Check-in accounting pair is corrupt');
  }
  return (canonicalOwner ?? accountingOwner ?? null) as string | null;
}

export async function deletePublishedCheckIn(
  db: Firestore,
  callerUid: string,
  checkInId: string,
): Promise<DeleteCheckInResult> {
  const canonicalRef = db.doc(`check_ins/${checkInId}`);
  const accountingRef = db.doc(`check_in_accounting/${checkInId}`);
  const tombstoneRef = db.doc(`check_in_tombstones/${checkInId}`);

  return db.runTransaction(async (transaction) => {
    const pairSnapshots = await transaction.getAll(
      canonicalRef,
      accountingRef,
      tombstoneRef,
    );
    const canonical = pairSnapshots[0]!;
    const accountingSnapshot = pairSnapshots[1]!;
    const tombstone = pairSnapshots[2]!;
    const tombstoneOwner = validateTombstone(tombstone);
    if (!canonical.exists && !accountingSnapshot.exists) {
      if (tombstoneOwner !== null && tombstoneOwner !== callerUid) {
        denied('Only the check-in owner may delete it', 'foreign_check_in');
      }
      return {checkInId, status: 'already-deleted' as const};
    }
    if (tombstoneOwner !== null) {
      failed('Check-in accounting pair conflicts with its tombstone');
    }
    if (!canonical.exists || !accountingSnapshot.exists) {
      failed('Check-in accounting pair is corrupt');
    }
    const ownerUid = ownerFrom(canonical, accountingSnapshot);
    if (ownerUid !== callerUid) {
      denied('Only the check-in owner may delete it', 'foreign_check_in');
    }
    const accounting = parseAccounting(accountingSnapshot);
    if (
      accounting.authorUid !== callerUid ||
      canonical.get('place_id') !== accounting.placeId
    ) {
      failed('Check-in accounting pair is corrupt');
    }
    validateAccountingAgainstCanonical(canonical, accounting);

    const userRefs = accounting.awardedPoints.map((entry) =>
      db.doc(`users/${entry.uid}`),
    );
    const visitRefs = accounting.visitCountDeltas.map((entry) =>
      db.doc(`users/${entry.uid}/place_visit_stats/${accounting.placeId}`),
    );
    const friendshipRefs = accounting.friendshipAffinityDeltas.map((entry) =>
      db.doc(`friendships/${entry.friendship_id}`),
    );
    const rollbackSnapshots = snapshotMap(
      await transaction.getAll(...userRefs, ...visitRefs, ...friendshipRefs),
    );

    accounting.awardedPoints.forEach((entry, index) => {
      const reference = userRefs[index]!;
      const snapshot = mappedSnapshot(rollbackSnapshots, reference);
      if (!snapshot.exists) failed(`${reference.path} is missing`);
      const points = nonNegativeInteger(
        snapshot.get('points'),
        `${reference.path}.points`,
      );
      transaction.update(reference, {
        points: Math.max(0, points - entry.points),
      });
    });
    accounting.visitCountDeltas.forEach((entry, index) => {
      const reference = visitRefs[index]!;
      const snapshot = mappedSnapshot(rollbackSnapshots, reference);
      const count = snapshot.exists
        ? nonNegativeInteger(snapshot.get('count'), `${reference.path}.count`)
        : 0;
      transaction.set(reference, {
        count: Math.max(0, count - entry.delta),
      });
    });
    accounting.friendshipAffinityDeltas.forEach((entry, index) => {
      const reference = friendshipRefs[index]!;
      const snapshot = mappedSnapshot(rollbackSnapshots, reference);
      if (!snapshot.exists) failed(`${reference.path} is missing`);
      const affinity = nonNegativeInteger(
        snapshot.get('affinity_score'),
        `${reference.path}.affinity_score`,
      );
      transaction.update(reference, {
        affinity_score: Math.max(0, affinity - entry.delta),
      });
    });
    transaction.delete(canonicalRef);
    transaction.delete(accountingRef);
    transaction.create(tombstoneRef, {
      owner_uid: callerUid,
      deleted_at: FieldValue.serverTimestamp(),
      schema_version: 1,
    });
    return {checkInId, status: 'deleted' as const};
  });
}
