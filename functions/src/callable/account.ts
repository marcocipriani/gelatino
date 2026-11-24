import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {callableOptions} from './options';
import {deleteAccountData} from '../services/account';

/** The client re-authenticates right before asking; older sessions must too. */
export const RECENT_LOGIN_SECONDS = 5 * 60;

export function signedInRecently(
  authTime: unknown,
  nowSeconds = Date.now() / 1000,
): boolean {
  return typeof authTime === 'number' &&
    nowSeconds - authTime <= RECENT_LOGIN_SECONDS;
}

export const deleteAccount = onCall(
  {...callableOptions, timeoutSeconds: 300},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required');
    }
    if (!signedInRecently(request.auth.token.auth_time)) {
      throw new HttpsError('failed-precondition', 'requires-recent-login');
    }
    const app = getApps()[0] ?? initializeApp();
    await deleteAccountData(
      getFirestore(app),
      getStorage(app).bucket(),
      getAuth(app),
      request.auth.uid,
    );
    return {ok: true};
  },
);
