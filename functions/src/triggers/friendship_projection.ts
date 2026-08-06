import {getApps, initializeApp} from 'firebase-admin/app';
import {Firestore, getFirestore} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import {pairId} from '../domain/ids';

const PATH_SEGMENT = /^[^/\u0000-\u001f\u007f]{1,128}$/u;

export type FriendshipProjectionHooks = {
  beforeFeedDeleteBatch?: () => Promise<void>;
};

class FriendshipEventValidationError extends Error {}
class FriendshipProjectionStateError extends Error {}

function invalidEvent(message: string): never {
  throw new FriendshipEventValidationError(message);
}

function invalidState(message: string): never {
  throw new FriendshipProjectionStateError(message);
}

function validateFriendship(
  friendshipId: string,
  value: unknown,
  source: 'event' | 'state' = 'event',
): {members: [string, string]; accepted: boolean} {
  const invalid = source === 'event' ? invalidEvent : invalidState;
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    invalid('friendship: must be an object');
  }
  const data = value as Record<string, unknown>;
  if (
    !Array.isArray(data.member_uids) ||
    data.member_uids.length !== 2 ||
    new Set(data.member_uids).size !== 2 ||
    data.member_uids.some(
      (uid) => typeof uid !== 'string' || !PATH_SEGMENT.test(uid),
    )
  ) {
    invalid('member_uids: is invalid');
  }
  const members = [...(data.member_uids as string[])].sort() as [string, string];
  if (pairId(members[0], members[1]) !== friendshipId) {
    invalid('friendshipId: does not match member_uids');
  }
  if (!['pending', 'accepted', 'declined', 'removed'].includes(data.state as string)) {
    invalid('state: is invalid');
  }
  return {members, accepted: data.state === 'accepted'};
}

async function crossAuthoredItems(
  db: Firestore,
  ownerUid: string,
  authorUid: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const items = await db.collection(`feeds/${ownerUid}/items`)
    .where('author_uid', '==', authorUid)
    .get();
  return items.docs;
}

async function reconcileFriendshipEdges(
  db: Firestore,
  friendshipId: string,
  fallback: {members: [string, string]; accepted: boolean},
) {
  const friendshipRef = db.doc(`friendships/${friendshipId}`);
  return db.runTransaction(async (transaction) => {
    const current = await transaction.get(friendshipRef);
    const selected = current.exists
      ? validateFriendship(friendshipId, current.data(), 'state')
      : fallback;
    const [firstUid, secondUid] = selected.members;
    const firstEdge = db.doc(
      `friend_access/${firstUid}/members/${secondUid}`,
    );
    const secondEdge = db.doc(
      `friend_access/${secondUid}/members/${firstUid}`,
    );
    if (selected.accepted) {
      const edge = {friendship_id: friendshipId};
      transaction.set(firstEdge, edge);
      transaction.set(secondEdge, edge);
    } else {
      transaction.delete(firstEdge);
      transaction.delete(secondEdge);
    }
    return selected;
  });
}

async function deleteFeedBatchesWhileNotAccepted(
  db: Firestore,
  friendshipId: string,
  items: FirebaseFirestore.QueryDocumentSnapshot[],
  hooks: FriendshipProjectionHooks,
): Promise<void> {
  const friendshipRef = db.doc(`friendships/${friendshipId}`);
  const batchSize = 200;
  for (let offset = 0; offset < items.length; offset += batchSize) {
    await hooks.beforeFeedDeleteBatch?.();
    const batch = items.slice(offset, offset + batchSize);
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(friendshipRef);
      if (
        current.exists &&
        validateFriendship(friendshipId, current.data(), 'state').accepted
      ) {
        return;
      }
      for (const item of batch) transaction.delete(item.ref);
    });
  }
}

export async function projectFriendshipChanged(
  db: Firestore,
  friendshipId: string,
  value: unknown,
  hooks: FriendshipProjectionHooks = {},
): Promise<void> {
  const eventProjection = validateFriendship(friendshipId, value);
  const projection = await reconcileFriendshipEdges(
    db,
    friendshipId,
    eventProjection,
  );
  if (projection.accepted) return;
  const [firstUid, secondUid] = projection.members;
  const [firstItems, secondItems] = await Promise.all([
    crossAuthoredItems(db, firstUid, secondUid),
    crossAuthoredItems(db, secondUid, firstUid),
  ]);
  await deleteFeedBatchesWhileNotAccepted(
    db,
    friendshipId,
    [...firstItems, ...secondItems],
    hooks,
  );
  await reconcileFriendshipEdges(db, friendshipId, eventProjection);
}

function database(): Firestore {
  const app = getApps()[0] ?? initializeApp();
  return getFirestore(app);
}

export const onFriendshipChanged = onDocumentWritten(
  {document: 'friendships/{friendshipId}', region: 'europe-west1'},
  async (event) => {
    const change = event.data;
    if (!change) return;
    const snapshot = change.after.exists ? change.after : change.before;
    const data = snapshot.data();
    if (!data) return;
    try {
      await projectFriendshipChanged(
        database(),
        event.params.friendshipId,
        change.after.exists ? data : {...data, state: 'removed'},
      );
    } catch (error) {
      if (!(error instanceof FriendshipEventValidationError)) throw error;
      console.error('Skipping invalid friendship projection event', {
        friendshipId: event.params.friendshipId,
        message: error.message,
      });
    }
  },
);
