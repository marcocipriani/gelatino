import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  deletePublishedCheckIn,
  publishCheckIn,
} from '../services/check_ins';

const options = {region: 'europe-west1', enforceAppCheck: false} as const;
const CHECK_IN_ID_PATTERN = /^[A-Za-z0-9_-]{20,64}$/;

function callerUid(auth: {uid: string} | undefined): string {
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }
  return auth.uid;
}

function checkInId(data: unknown): string {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Input must be an object');
  }
  const input = data as Record<string, unknown>;
  if (
    Object.keys(input).length !== 1 ||
    typeof input.checkInId !== 'string' ||
    !CHECK_IN_ID_PATTERN.test(input.checkInId)
  ) {
    throw new HttpsError('invalid-argument', 'checkInId is invalid');
  }
  return input.checkInId;
}

function services() {
  const app = getApps()[0] ?? initializeApp();
  return {
    db: getFirestore(app),
    bucket: getStorage(app).bucket(),
  };
}

export const createCheckIn = onCall(options, async (request) => {
  const uid = callerUid(request.auth);
  const {db, bucket} = services();
  return publishCheckIn(db, bucket, uid, request.data);
});

export const deleteCheckIn = onCall(options, async (request) => {
  const uid = callerUid(request.auth);
  return deletePublishedCheckIn(
    services().db,
    uid,
    checkInId(request.data),
  );
});
