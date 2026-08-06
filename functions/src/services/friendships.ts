import {
  DocumentData,
  FieldValue,
  Firestore,
} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import type {
  FriendshipState,
  RespondFriendRequestInput,
} from '../domain/contracts';
import {pairId} from '../domain/ids';

export type FriendshipResult = {
  friendshipId: string;
  state: FriendshipState;
  requesterUid: string;
  recipientUid: string;
};

const friendshipStates = new Set<FriendshipState>([
  'pending',
  'accepted',
  'declined',
  'removed',
]);

function validatePair(callerUid: string, otherUid: string): void {
  if (!callerUid || !otherUid || callerUid === otherUid) {
    throw new HttpsError(
      'invalid-argument',
      'otherUid must identify another user',
    );
  }
}

function members(callerUid: string, otherUid: string): [string, string] {
  return [callerUid, otherUid].sort() as [string, string];
}

function friendshipResult(
  friendshipId: string,
  data: DocumentData,
): FriendshipResult {
  const state = data.state as FriendshipState;
  if (
    !friendshipStates.has(state) ||
    typeof data.requester_uid !== 'string' ||
    typeof data.recipient_uid !== 'string'
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Friendship data is invalid',
    );
  }
  return {
    friendshipId,
    state,
    requesterUid: data.requester_uid,
    recipientUid: data.recipient_uid,
  };
}

function requireMembers(
  data: DocumentData,
  callerUid: string,
  otherUid: string,
): void {
  if (
    !Array.isArray(data.member_uids) ||
    !data.member_uids.includes(callerUid) ||
    !data.member_uids.includes(otherUid)
  ) {
    throw new HttpsError(
      'permission-denied',
      'Caller is not a friendship member',
    );
  }
}

export async function sendRequest(
  db: Firestore,
  callerUid: string,
  otherUid: string,
): Promise<FriendshipResult> {
  validatePair(callerUid, otherUid);
  const friendshipId = pairId(callerUid, otherUid);
  const friendshipRef = db.doc(`friendships/${friendshipId}`);
  const profileRef = db.doc(`public_profiles/${otherUid}`);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(
      profileRef,
      friendshipRef,
    );
    const profileSnapshot = snapshots[0]!;
    const friendshipSnapshot = snapshots[1]!;
    if (!profileSnapshot.exists) {
      throw new HttpsError('not-found', 'Public profile not found');
    }

    if (!friendshipSnapshot.exists) {
      const [lowerUid, higherUid] = members(callerUid, otherUid);
      const timestamp = FieldValue.serverTimestamp();
      transaction.create(friendshipRef, {
        member_uids: [lowerUid, higherUid],
        requester_uid: callerUid,
        recipient_uid: otherUid,
        state: 'pending',
        requested_at: timestamp,
        responded_at: null,
        accepted_at: null,
        removed_at: null,
        affinity_score: 0,
        updated_at: timestamp,
      });
      return {
        friendshipId,
        state: 'pending',
        requesterUid: callerUid,
        recipientUid: otherUid,
      };
    }

    const data = friendshipSnapshot.data()!;
    requireMembers(data, callerUid, otherUid);
    const current = friendshipResult(friendshipId, data);
    if (current.state === 'pending' || current.state === 'accepted') {
      return current;
    }

    const timestamp = FieldValue.serverTimestamp();
    transaction.update(friendshipRef, {
      requester_uid: callerUid,
      recipient_uid: otherUid,
      state: 'pending',
      requested_at: timestamp,
      responded_at: null,
      accepted_at: null,
      removed_at: null,
      updated_at: timestamp,
    });
    return {
      friendshipId,
      state: 'pending',
      requesterUid: callerUid,
      recipientUid: otherUid,
    };
  });
}

export async function respondToRequest(
  db: Firestore,
  callerUid: string,
  input: RespondFriendRequestInput,
): Promise<FriendshipResult> {
  validatePair(callerUid, input.otherUid);
  const friendshipId = pairId(callerUid, input.otherUid);
  const friendshipRef = db.doc(`friendships/${friendshipId}`);
  const profileRef = db.doc(`public_profiles/${input.otherUid}`);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(
      profileRef,
      friendshipRef,
    );
    const profileSnapshot = snapshots[0]!;
    const friendshipSnapshot = snapshots[1]!;
    if (!profileSnapshot.exists) {
      throw new HttpsError('not-found', 'Public profile not found');
    }
    if (!friendshipSnapshot.exists) {
      throw new HttpsError('not-found', 'Friendship not found');
    }

    const data = friendshipSnapshot.data()!;
    requireMembers(data, callerUid, input.otherUid);
    const current = friendshipResult(friendshipId, data);
    if (current.recipientUid !== callerUid) {
      throw new HttpsError(
        'permission-denied',
        'Only the request recipient may respond',
      );
    }
    if (current.state === 'accepted' && input.response === 'accepted') {
      return current;
    }
    if (current.state !== 'pending') {
      throw new HttpsError(
        'failed-precondition',
        'Friend request is no longer pending',
      );
    }

    const timestamp = FieldValue.serverTimestamp();
    transaction.update(friendshipRef, {
      state: input.response,
      responded_at: timestamp,
      accepted_at:
        input.response === 'accepted' ? timestamp : null,
      removed_at: null,
      updated_at: timestamp,
    });

    const [lowerUid, higherUid] = members(callerUid, input.otherUid);
    const lowerEdge = db.doc(
      `friend_access/${lowerUid}/members/${higherUid}`,
    );
    const higherEdge = db.doc(
      `friend_access/${higherUid}/members/${lowerUid}`,
    );
    if (input.response === 'accepted') {
      const edge = {friendship_id: friendshipId};
      transaction.set(lowerEdge, edge);
      transaction.set(higherEdge, edge);
    } else {
      transaction.delete(lowerEdge);
      transaction.delete(higherEdge);
    }

    return {...current, state: input.response};
  });
}

export async function removeAcceptedFriendship(
  db: Firestore,
  callerUid: string,
  otherUid: string,
): Promise<FriendshipResult> {
  validatePair(callerUid, otherUid);
  const friendshipId = pairId(callerUid, otherUid);
  const friendshipRef = db.doc(`friendships/${friendshipId}`);
  const profileRef = db.doc(`public_profiles/${otherUid}`);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(
      profileRef,
      friendshipRef,
    );
    const profileSnapshot = snapshots[0]!;
    const friendshipSnapshot = snapshots[1]!;
    if (!profileSnapshot.exists) {
      throw new HttpsError('not-found', 'Public profile not found');
    }
    if (!friendshipSnapshot.exists) {
      throw new HttpsError('not-found', 'Friendship not found');
    }

    const data = friendshipSnapshot.data()!;
    requireMembers(data, callerUid, otherUid);
    const current = friendshipResult(friendshipId, data);
    if (current.state !== 'accepted') {
      throw new HttpsError(
        'failed-precondition',
        'Only accepted friendships may be removed',
      );
    }

    const timestamp = FieldValue.serverTimestamp();
    transaction.update(friendshipRef, {
      state: 'removed',
      removed_at: timestamp,
      updated_at: timestamp,
    });
    const [lowerUid, higherUid] = members(callerUid, otherUid);
    transaction.delete(
      db.doc(`friend_access/${lowerUid}/members/${higherUid}`),
    );
    transaction.delete(
      db.doc(`friend_access/${higherUid}/members/${lowerUid}`),
    );
    return {...current, state: 'removed'};
  });
}
