import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  removeAcceptedFriendship,
  respondToRequest,
  sendRequest,
} from '../services/friendships';

const options = {region: 'europe-west1', enforceAppCheck: false} as const;

function callerUid(auth: {uid: string} | undefined): string {
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }
  return auth.uid;
}

function inputRecord(data: unknown): Record<string, unknown> {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Input must be an object');
  }
  return data as Record<string, unknown>;
}

function otherUid(data: unknown): string {
  const value = inputRecord(data).otherUid;
  if (
    typeof value !== 'string' ||
    Array.from(value).length === 0 ||
    Array.from(value).length > 128 ||
    value.includes('/') ||
    /[\u0000-\u001f\u007f]/u.test(value)
  ) {
    throw new HttpsError('invalid-argument', 'otherUid is invalid');
  }
  return value;
}

function database() {
  const app = getApps()[0] ?? initializeApp();
  return getFirestore(app);
}

export const sendFriendRequest = onCall(options, async (request) => {
  const uid = callerUid(request.auth);
  return sendRequest(database(), uid, otherUid(request.data));
});

export const respondToFriendRequest = onCall(options, async (request) => {
  const uid = callerUid(request.auth);
  const input = inputRecord(request.data);
  const targetUid = otherUid(input);
  if (input.response !== 'accepted' && input.response !== 'declined') {
    throw new HttpsError(
      'invalid-argument',
      'response must be accepted or declined',
    );
  }
  return respondToRequest(database(), uid, {
    otherUid: targetUid,
    response: input.response,
  });
});

export const removeFriendship = onCall(options, async (request) => {
  const uid = callerUid(request.auth);
  return removeAcceptedFriendship(
    database(),
    uid,
    otherUid(request.data),
  );
});
