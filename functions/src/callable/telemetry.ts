import {logger} from 'firebase-functions';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {callableOptions} from './options';

const KINDS = new Set(['media_load', 'media_decode', 'photo_upload']);
const PLATFORMS = new Set(['web', 'android', 'ios', 'other']);
const CODE = /^[a-z0-9_/-]{1,64}$/;

/** Per-instance budget; best effort against a client flooding the logs. */
const MAX_REPORTS_PER_UID = 50;
const reportsByUid = new Map<string, number>();

export type ClientFailureReport = {kind: string; code: string; platform: string};

export function parseClientFailureReport(data: unknown): ClientFailureReport {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Input must be an object');
  }
  const input = data as Record<string, unknown>;
  const {kind, code, platform} = input;
  if (
    Object.keys(input).length !== 3 ||
    typeof kind !== 'string' || !KINDS.has(kind) ||
    typeof code !== 'string' || !CODE.test(code) ||
    typeof platform !== 'string' || !PLATFORMS.has(platform)
  ) {
    throw new HttpsError('invalid-argument', 'Report is invalid');
  }
  return {kind, code, platform};
}

export function underBudget(uid: string, counts = reportsByUid): boolean {
  const count = (counts.get(uid) ?? 0) + 1;
  counts.set(uid, count);
  return count <= MAX_REPORTS_PER_UID;
}

/**
 * Records a client-side image failure in Cloud Logging, where it can be
 * counted with a log-based metric. Carries no paths or messages: only the
 * failure kind, a short error code and the platform.
 */
export const reportClientFailure = onCall(callableOptions, (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required');
  }
  const report = parseClientFailureReport(request.data);
  if (underBudget(request.auth.uid)) {
    logger.warn('client_media_failure', {uid: request.auth.uid, ...report});
  }
  return {ok: true};
});
