import {getApps, initializeApp} from 'firebase-admin/app';
import type {Storage} from 'firebase-admin/storage';
import {getStorage} from 'firebase-admin/storage';
import {
  DocumentData,
  DocumentReference,
  DocumentSnapshot,
  FieldValue,
  Firestore,
  QueryDocumentSnapshot,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {
  onDocumentCreated,
  onDocumentDeleted,
} from 'firebase-functions/v2/firestore';
import {pairId} from '../domain/ids';

type StorageBucket = ReturnType<Storage['bucket']>;

type CheckInProjection = {
  authorUid: string;
  placeId: string;
  rating: number;
  feedItem: Record<string, unknown>;
};

export type CheckInProjectionHooks = {
  afterCandidateQuery?: () => Promise<void>;
};

const CHECK_IN_ID = /^[A-Za-z0-9_-]{20,64}$/;
const PATH_SEGMENT = /^[^/\u0000-\u001f\u007f]{1,128}$/u;
const EVENT_ID = /^[^/\u0000-\u001f\u007f]{1,512}$/u;

class CheckInEventValidationError extends Error {}
class CheckInProjectionStateError extends Error {}

const HEX_COLOR = /^#[0-9A-Fa-f]{6}$/;

function invalidEvent(message: string): never {
  throw new CheckInEventValidationError(message);
}

function invalidState(message: string): never {
  throw new CheckInProjectionStateError(message);
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    invalidEvent(`${label}: must be an object`);
  }
  return value as Record<string, unknown>;
}

function exactRecord(
  value: unknown,
  keys: string[],
  label: string,
): Record<string, unknown> {
  const data = record(value, label);
  const actual = Object.keys(data).sort();
  const expected = [...keys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    invalidEvent(`${label}: has invalid fields`);
  }
  return data;
}

function pathSegment(value: unknown, label: string): string {
  if (typeof value !== 'string' || !PATH_SEGMENT.test(value)) {
    invalidEvent(`${label}: is invalid`);
  }
  return value;
}

function displayString(value: unknown, label: string): string {
  if (typeof value !== 'string') invalidEvent(`${label}: is invalid`);
  return value;
}

function validateNestedSnapshot(
  value: unknown,
  keys: string[],
  label: string,
): Record<string, unknown> {
  const data = exactRecord(value, keys, label);
  for (const key of keys) {
    const field = data[key];
    if (key === 'avatar_path') {
      if (field !== null && typeof field !== 'string') {
        invalidEvent(`${label}.${key}: is invalid`);
      }
    } else {
      displayString(field, `${label}.${key}`);
    }
  }
  return data;
}

function validateFlavorSnapshot(
  value: unknown,
  label: string,
): Record<string, unknown> {
  const data = record(value, label);
  const keys = Object.keys(data);
  if (
    !keys.includes('id') ||
    !keys.includes('name') ||
    keys.some((key) => key !== 'id' && key !== 'name' && key !== 'color_hex')
  ) {
    invalidEvent(`${label}: has invalid fields`);
  }
  displayString(data.id, `${label}.id`);
  displayString(data.name, `${label}.name`);
  if ('color_hex' in data) {
    const colorHex = data.color_hex;
    if (colorHex !== null && (typeof colorHex !== 'string' || !HEX_COLOR.test(colorHex))) {
      invalidEvent(`${label}.color_hex: is invalid`);
    }
  }
  return data;
}

export function validateCheckIn(
  checkInId: string,
  value: unknown,
): CheckInProjection {
  if (!CHECK_IN_ID.test(checkInId)) invalidEvent('checkInId: is invalid');
  const data = record(value, 'checkIn');
  const authorUid = pathSegment(data.user_id, 'user_id');
  const placeId = pathSegment(data.place_id, 'place_id');
  if (!Number.isSafeInteger(data.rating) || (data.rating as number) < 1 ||
      (data.rating as number) > 5) {
    invalidEvent('rating: is invalid');
  }
  if (typeof data.review_text !== 'string' || data.review_text.length > 500) {
    invalidEvent('review_text: is invalid');
  }
  if (!(data.created_at instanceof Timestamp)) {
    invalidEvent('created_at: must be a Timestamp');
  }
  // Optional: check-ins written before backdating shipped have no consumed_at,
  // and they must keep projecting. Absent falls back to created_at, so every
  // feed item carries the field even when the source document does not.
  if ('consumed_at' in data && !(data.consumed_at instanceof Timestamp)) {
    invalidEvent('consumed_at: must be a Timestamp');
  }
  const consumedAt = data.consumed_at ?? data.created_at;
  if (data.schema_version !== 2) invalidEvent('schema_version: is invalid');

  const userSnapshot = validateNestedSnapshot(
    data.user_snapshot,
    ['display_name', 'username', 'avatar_path'],
    'user_snapshot',
  );
  const placeSnapshot = validateNestedSnapshot(
    data.place_snapshot,
    ['name', 'address'],
    'place_snapshot',
  );
  const gelatoType = validateNestedSnapshot(
    data.gelato_type,
    ['id', 'name'],
    'gelato_type',
  );
  if (!Array.isArray(data.flavors) || data.flavors.length < 1 ||
      data.flavors.length > 4) {
    invalidEvent('flavors: is invalid');
  }
  const flavors = data.flavors.map((flavor, index) =>
    validateFlavorSnapshot(flavor, `flavors[${index}]`),
  );
  if (!Array.isArray(data.tagged_user_ids) ||
      data.tagged_user_ids.length > 10) {
    invalidEvent('tagged_user_ids: is invalid');
  }
  const taggedUserIds = data.tagged_user_ids.map((uid, index) =>
    pathSegment(uid, `tagged_user_ids[${index}]`),
  );
  if (
    taggedUserIds.includes(authorUid) ||
    new Set(taggedUserIds).size !== taggedUserIds.length
  ) {
    invalidEvent('tagged_user_ids: is invalid');
  }
  const photoStoragePath = data.photo_storage_path;
  const expectedPrefix = `check_ins/${authorUid}/${checkInId}/`;
  if (
    typeof photoStoragePath !== 'string' ||
    !photoStoragePath.startsWith(expectedPrefix) ||
    photoStoragePath.slice(expectedPrefix.length).length === 0 ||
    photoStoragePath.slice(expectedPrefix.length).includes('/')
  ) {
    invalidEvent('photo_storage_path: is invalid');
  }

  return {
    authorUid,
    placeId,
    rating: data.rating as number,
    feedItem: {
      author_uid: authorUid,
      check_in_id: checkInId,
      user_snapshot: userSnapshot,
      place_id: placeId,
      place_snapshot: placeSnapshot,
      gelato_type: gelatoType,
      flavors,
      rating: data.rating,
      review_text: data.review_text,
      tagged_user_ids: taggedUserIds,
      created_at: data.created_at,
      consumed_at: consumedAt,
      photo_storage_path: photoStoragePath,
    },
  };
}

function validateEventId(eventId: string): void {
  if (!EVENT_ID.test(eventId)) invalidEvent('eventId: is invalid');
}

function safeNonNegative(value: unknown, label: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) {
    invalidState(`${label}: is invalid`);
  }
  return value as number;
}

function safeAdd(left: number, right: number, label: string): number {
  const result = left + right;
  if (!Number.isSafeInteger(result) || result < 0) {
    invalidState(`${label}: exceeds safe integer range`);
  }
  return result;
}

function aggregateValues(data: DocumentData | undefined): {
  count: number;
  sum: number;
} {
  if (!data) return {count: 0, sum: 0};
  return {
    count: safeNonNegative(data.check_in_count, 'check_in_count'),
    sum: safeNonNegative(data.rating_sum, 'rating_sum'),
  };
}

type ProjectionLifecycle = {
  state: 'counted' | 'deleted';
  authorUid: string;
  placeId: string;
  rating: number;
};

type ExactFeedReference = {
  ownerUid: string;
  reference: DocumentReference;
};

function internalPathSegment(value: unknown, label: string): string {
  if (typeof value !== 'string' || !PATH_SEGMENT.test(value)) {
    invalidState(`${label}: is invalid`);
  }
  return value;
}

function lifecycleState(
  snapshot: DocumentSnapshot,
  projection: CheckInProjection,
): ProjectionLifecycle | null {
  if (!snapshot.exists) return null;
  const data = snapshot.data()!;
  if (
    !['counted', 'deleted'].includes(data.state) ||
    !(data.updated_at instanceof Timestamp)
  ) {
    invalidState(`${snapshot.ref.path}: is invalid`);
  }
  const state = {
    state: data.state as ProjectionLifecycle['state'],
    authorUid: internalPathSegment(
      data.author_uid,
      `${snapshot.ref.path}.author_uid`,
    ),
    placeId: internalPathSegment(
      data.place_id,
      `${snapshot.ref.path}.place_id`,
    ),
    rating: safeNonNegative(data.rating, `${snapshot.ref.path}.rating`),
  };
  if (
    state.rating < 1 ||
    state.rating > 5 ||
    state.authorUid !== projection.authorUid ||
    state.placeId !== projection.placeId ||
    state.rating !== projection.rating
  ) {
    invalidState(`${snapshot.ref.path}: does not match check-in event`);
  }
  return state;
}

function lifecycleData(
  state: ProjectionLifecycle['state'],
  projection: CheckInProjection,
) {
  return {
    state,
    author_uid: projection.authorUid,
    place_id: projection.placeId,
    rating: projection.rating,
    updated_at: FieldValue.serverTimestamp(),
  };
}

function hasValidReceipt(
  snapshot: DocumentSnapshot,
  checkInId: string,
): boolean {
  if (!snapshot.exists) return false;
  const data = snapshot.data()!;
  const keys = Object.keys(data).sort();
  if (
    keys.length !== 2 ||
    keys[0] !== 'check_in_id' ||
    keys[1] !== 'created_at' ||
    data.check_in_id !== checkInId ||
    !(data.created_at instanceof Timestamp)
  ) {
    invalidState(`${snapshot.ref.path}: is invalid`);
  }
  return true;
}

function acceptedRecipients(
  authorUid: string,
  friendships: FirebaseFirestore.QuerySnapshot,
): string[] {
  const recipients = new Set([authorUid]);
  for (const friendship of friendships.docs) {
    const data = friendship.data();
    if (data.state !== 'accepted') continue;
    if (
      !Array.isArray(data.member_uids) ||
      data.member_uids.length !== 2 ||
      new Set(data.member_uids).size !== 2 ||
      !data.member_uids.includes(authorUid)
    ) {
      invalidState(`${friendship.ref.path}.member_uids: is invalid`);
    }
    const otherUid = data.member_uids.find((uid: unknown) => uid !== authorUid);
    const recipientUid = internalPathSegment(
      otherUid,
      `${friendship.ref.path}.member_uids`,
    );
    if (friendship.id !== pairId(authorUid, recipientUid)) {
      invalidState(`${friendship.ref.path}: friendship ID is invalid`);
    }
    recipients.add(recipientUid);
  }
  return [...recipients];
}

function acceptedCanonicalFriendship(
  friendship: DocumentSnapshot,
  authorUid: string,
  otherUid: string,
): boolean {
  if (!friendship.exists) return false;
  const data = friendship.data()!;
  if (
    !Array.isArray(data.member_uids) ||
    data.member_uids.length !== 2 ||
    new Set(data.member_uids).size !== 2 ||
    !data.member_uids.includes(authorUid) ||
    !data.member_uids.includes(otherUid) ||
    friendship.id !== pairId(authorUid, otherUid) ||
    !['pending', 'accepted', 'declined', 'removed'].includes(data.state)
  ) {
    invalidState(`${friendship.ref.path}: is invalid`);
  }
  return data.state === 'accepted';
}

async function updateCreatedAggregate(
  db: Firestore,
  projection: CheckInProjection,
  checkInId: string,
  eventId: string,
): Promise<'counted' | 'deleted'> {
  const receiptRef = db.doc(`event_receipts/checkin-created-${eventId}`);
  const aggregateRef = db.doc(`place_aggregates/${projection.placeId}`);
  const tombstoneRef = db.doc(`check_in_tombstones/${checkInId}`);
  const lifecycleRef = db.doc(`check_in_projection_states/${checkInId}`);
  return db.runTransaction(async (transaction) => {
    const [receipt, aggregate, tombstone, lifecycle] = await transaction.getAll(
      receiptRef,
      aggregateRef,
      tombstoneRef,
      lifecycleRef,
    );
    const currentLifecycle = lifecycleState(lifecycle!, projection);
    if (hasValidReceipt(receipt!, checkInId)) {
      if (!currentLifecycle) {
        invalidState(`${receiptRef.path}: exists without lifecycle state`);
      }
      return tombstone!.exists || currentLifecycle.state === 'deleted'
        ? 'deleted'
        : 'counted';
    }
    if (tombstone!.exists || currentLifecycle?.state === 'deleted') {
      if (!currentLifecycle) {
        transaction.create(lifecycleRef, lifecycleData('deleted', projection));
      }
      transaction.create(receiptRef, {
        check_in_id: checkInId,
        created_at: FieldValue.serverTimestamp(),
      });
      return 'deleted';
    }
    if (currentLifecycle?.state === 'counted') {
      transaction.create(receiptRef, {
        check_in_id: checkInId,
        created_at: FieldValue.serverTimestamp(),
      });
      return 'counted';
    }
    const current = aggregateValues(aggregate!.data());
    const count = safeAdd(current.count, 1, 'check_in_count');
    const sum = safeAdd(current.sum, projection.rating, 'rating_sum');
    transaction.set(aggregateRef, {
      check_in_count: count,
      rating_sum: sum,
      rating_average: sum / count,
      updated_at: FieldValue.serverTimestamp(),
    });
    transaction.create(lifecycleRef, lifecycleData('counted', projection));
    transaction.create(receiptRef, {
      check_in_id: checkInId,
      created_at: FieldValue.serverTimestamp(),
    });
    return 'counted';
  });
}

function exactFeedReference(
  snapshot: QueryDocumentSnapshot,
  checkInId: string,
): ExactFeedReference | null {
  const parts = snapshot.ref.path.split('/');
  if (
    parts.length !== 4 ||
    parts[0] !== 'feeds' ||
    parts[2] !== 'items' ||
    parts[3] !== checkInId ||
    snapshot.id !== checkInId ||
    !PATH_SEGMENT.test(parts[1] ?? '')
  ) {
    return null;
  }
  return {ownerUid: parts[1]!, reference: snapshot.ref};
}

async function exactFeedReferences(
  db: Firestore,
  checkInId: string,
): Promise<ExactFeedReference[]> {
  const matches = await db.collectionGroup('items')
    .where('check_in_id', '==', checkInId)
    .get();
  return matches.docs.flatMap((snapshot) => {
    const reference = exactFeedReference(snapshot, checkInId);
    return reference ? [reference] : [];
  });
}

async function deleteFeedReferences(
  db: Firestore,
  checkInId: string,
): Promise<void> {
  const matches = await exactFeedReferences(db, checkInId);
  const writer = db.bulkWriter();
  for (const item of matches) writer.delete(item.reference);
  await writer.close();
}

async function reconcileFeedRecipient(
  db: Firestore,
  checkInId: string,
  projection: CheckInProjection,
  ownerUid: string,
): Promise<void> {
  const feedRef = db.doc(`feeds/${ownerUid}/items/${checkInId}`);
  const tombstoneRef = db.doc(`check_in_tombstones/${checkInId}`);
  const friendshipRef = ownerUid === projection.authorUid
    ? null
    : db.doc(`friendships/${pairId(projection.authorUid, ownerUid)}`);
  await db.runTransaction(async (transaction) => {
    const snapshots = friendshipRef
      ? await transaction.getAll(tombstoneRef, friendshipRef)
      : [await transaction.get(tombstoneRef)];
    const tombstone = snapshots[0]!;
    const mayRead = ownerUid === projection.authorUid ||
      (friendshipRef !== null && acceptedCanonicalFriendship(
        snapshots[1]!,
        projection.authorUid,
        ownerUid,
      ));
    if (tombstone.exists || !mayRead) {
      transaction.delete(feedRef);
    } else {
      transaction.set(feedRef, projection.feedItem);
    }
  });
}

async function reconcileCheckInFeeds(
  db: Firestore,
  checkInId: string,
  projection: CheckInProjection,
  projectedRecipients: string[],
): Promise<void> {
  const existing = await exactFeedReferences(db, checkInId);
  const recipients = [...new Set([
    projection.authorUid,
    ...projectedRecipients,
    ...existing.map((item) => item.ownerUid),
  ])];
  const batchSize = 50;
  for (let offset = 0; offset < recipients.length; offset += batchSize) {
    await Promise.all(
      recipients.slice(offset, offset + batchSize).map((uid) =>
        reconcileFeedRecipient(db, checkInId, projection, uid),
      ),
    );
  }
}

export async function projectCheckInCreated(
  db: Firestore,
  checkInId: string,
  eventId: string,
  value: unknown,
  hooks: CheckInProjectionHooks = {},
): Promise<void> {
  validateEventId(eventId);
  const projection = validateCheckIn(checkInId, value);
  const tombstoneRef = db.doc(`check_in_tombstones/${checkInId}`);
  if ((await tombstoneRef.get()).exists) {
    await updateCreatedAggregate(db, projection, checkInId, eventId);
    await reconcileCheckInFeeds(db, checkInId, projection, []);
    return;
  }

  const friendships = await db.collection('friendships')
    .where('member_uids', 'array-contains', projection.authorUid)
    .get();
  const recipients = acceptedRecipients(projection.authorUid, friendships);
  if (await updateCreatedAggregate(db, projection, checkInId, eventId) ===
      'deleted') {
    await reconcileCheckInFeeds(db, checkInId, projection, recipients);
    return;
  }

  await hooks.afterCandidateQuery?.();
  await reconcileCheckInFeeds(db, checkInId, projection, recipients);
}

async function updateDeletedAggregate(
  db: Firestore,
  projection: CheckInProjection,
  checkInId: string,
  eventId: string,
): Promise<void> {
  const receiptRef = db.doc(`event_receipts/checkin-deleted-${eventId}`);
  const aggregateRef = db.doc(`place_aggregates/${projection.placeId}`);
  const lifecycleRef = db.doc(`check_in_projection_states/${checkInId}`);
  await db.runTransaction(async (transaction) => {
    const [receipt, aggregate, lifecycle] = await transaction.getAll(
      receiptRef,
      aggregateRef,
      lifecycleRef,
    );
    const currentLifecycle = lifecycleState(lifecycle!, projection);
    if (hasValidReceipt(receipt!, checkInId)) {
      if (!currentLifecycle) {
        invalidState(`${receiptRef.path}: exists without lifecycle state`);
      }
      if (currentLifecycle.state !== 'deleted') {
        invalidState(`${receiptRef.path}: requires deleted lifecycle`);
      }
      return;
    }
    if (!currentLifecycle || currentLifecycle.state === 'deleted') {
      if (!currentLifecycle) {
        transaction.create(lifecycleRef, lifecycleData('deleted', projection));
      }
      transaction.create(receiptRef, {
        check_in_id: checkInId,
        created_at: FieldValue.serverTimestamp(),
      });
      return;
    }
    const current = aggregateValues(aggregate!.data());
    const count = Math.max(0, current.count - 1);
    const sum = count === 0 ? 0 : Math.max(0, current.sum - projection.rating);
    transaction.set(aggregateRef, {
      check_in_count: count,
      rating_sum: sum,
      rating_average: count === 0 ? 0 : sum / count,
      updated_at: FieldValue.serverTimestamp(),
    });
    transaction.set(lifecycleRef, lifecycleData('deleted', projection));
    transaction.create(receiptRef, {
      check_in_id: checkInId,
      created_at: FieldValue.serverTimestamp(),
    });
  });
}

export async function projectCheckInDeleted(
  db: Firestore,
  bucket: StorageBucket,
  checkInId: string,
  eventId: string,
  value: unknown,
): Promise<void> {
  validateEventId(eventId);
  const projection = validateCheckIn(checkInId, value);
  await updateDeletedAggregate(db, projection, checkInId, eventId);
  await deleteFeedReferences(db, checkInId);
  await bucket.deleteFiles({prefix: `check_ins/${projection.authorUid}/${checkInId}/`});
}

function database(): Firestore {
  const app = getApps()[0] ?? initializeApp();
  return getFirestore(app);
}

function services(): {db: Firestore; bucket: StorageBucket} {
  const app = getApps()[0] ?? initializeApp();
  return {db: getFirestore(app), bucket: getStorage(app).bucket()};
}

export const onCheckInCreated = onDocumentCreated(
  {document: 'check_ins/{checkInId}', region: 'europe-west1'},
  async (event) => {
    if (!event.data) return;
    try {
      await projectCheckInCreated(
        database(),
        event.params.checkInId,
        event.id,
        event.data.data(),
      );
    } catch (error) {
      if (!(error instanceof CheckInEventValidationError)) throw error;
      console.error('Skipping invalid check-in create projection event', {
        checkInId: event.params.checkInId,
        message: error.message,
      });
    }
  },
);

export const onCheckInDeleted = onDocumentDeleted(
  {document: 'check_ins/{checkInId}', region: 'europe-west1'},
  async (event) => {
    if (!event.data) return;
    const {db, bucket} = services();
    try {
      await projectCheckInDeleted(
        db,
        bucket,
        event.params.checkInId,
        event.id,
        event.data.data(),
      );
    } catch (error) {
      if (!(error instanceof CheckInEventValidationError)) throw error;
      console.error('Skipping invalid check-in delete projection event', {
        checkInId: event.params.checkInId,
        message: error.message,
      });
    }
  },
);
