import {getApps, initializeApp} from 'firebase-admin/app';
import {
  Firestore,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import type {PublicProfile} from '../domain/contracts';

const PATH_SEGMENT = /^[^/\u0000-\u001f\u007f]{1,128}$/u;
const MONTH_KEY = /^\d{4}-(0[1-9]|1[0-2])$/;
const VISIBILITIES = new Set(['public', 'friends', 'private']);

class ProfileProjectionValidationError extends Error {}

function invalid(message: string): never {
  throw new ProfileProjectionValidationError(message);
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    invalid('privateData: must be an object');
  }
  return value as Record<string, unknown>;
}

function optionalStringField(
  data: Record<string, unknown>,
  key: string,
): string {
  const value = data[key];
  if (value === undefined) return '';
  if (typeof value !== 'string') invalid(`${key}: must be a string`);
  return value;
}

function nullableStringField(
  data: Record<string, unknown>,
  key: string,
): string | null {
  const value = data[key];
  if (value === undefined) return null;
  if (value !== null && typeof value !== 'string') {
    invalid(`${key}: must be a string or null`);
  }
  return value;
}

export function toPublicProfile(
  uid: string,
  privateData: unknown,
  now: Timestamp,
): Readonly<PublicProfile> {
  if (!PATH_SEGMENT.test(uid)) invalid('uid: is invalid');
  if (!(now instanceof Timestamp)) invalid('now: must be a Timestamp');
  const data = record(privateData);
  const favoriteFlavorIds = data.favorite_flavor_ids ?? [];
  if (
    !Array.isArray(favoriteFlavorIds) ||
    favoriteFlavorIds.some((value) => typeof value !== 'string') ||
    new Set(favoriteFlavorIds).size !== favoriteFlavorIds.length
  ) {
    invalid('favorite_flavor_ids: must be unique strings');
  }
  const visibility = data.profile_visibility ?? 'private';
  if (!VISIBILITIES.has(visibility as string)) {
    invalid('profile_visibility: is invalid');
  }
  const searchable = data.searchable ?? false;
  if (typeof searchable !== 'boolean') {
    invalid('searchable: must be a boolean');
  }
  const points = data.points ?? 0;
  if (!Number.isSafeInteger(points) || (points as number) < 0) {
    invalid('points: must be a non-negative safe integer');
  }
  const monthlyRaw = data.monthly_points ?? {};
  if (
    typeof monthlyRaw !== 'object' ||
    monthlyRaw === null ||
    Array.isArray(monthlyRaw)
  ) {
    invalid('monthly_points: must be an object');
  }
  const monthlyPoints: Record<string, number> = {};
  for (const [key, value] of Object.entries(
    monthlyRaw as Record<string, unknown>,
  )) {
    if (!MONTH_KEY.test(key)) invalid('monthly_points: invalid month key');
    if (!Number.isSafeInteger(value) || (value as number) < 0) {
      invalid('monthly_points: must be non-negative safe integers');
    }
    monthlyPoints[key] = value as number;
  }

  const displayName = optionalStringField(data, 'display_name');
  const username = optionalStringField(data, 'username');

  const profile: PublicProfile = {
    uid,
    display_name: displayName,
    display_name_lower: displayName.toLowerCase(),
    username,
    username_lower: username.toLowerCase(),
    avatar_path: nullableStringField(data, 'avatar_path'),
    bio: optionalStringField(data, 'bio'),
    city: optionalStringField(data, 'city'),
    favorite_place_id: nullableStringField(data, 'favorite_place_id'),
    favorite_flavor_id: nullableStringField(data, 'favorite_flavor_id'),
    favorite_flavor_ids: Object.freeze([...favoriteFlavorIds]) as string[],
    profile_visibility: visibility as PublicProfile['profile_visibility'],
    searchable,
    points: points as number,
    monthly_points: monthlyPoints,
    updated_at: now,
  };
  return Object.freeze(profile);
}

export async function syncPublicProfile(
  db: Firestore,
  uid: string,
  privateData: unknown | null,
  now: Timestamp,
): Promise<void> {
  if (!PATH_SEGMENT.test(uid)) invalid('uid: is invalid');
  const reference = db.doc(`public_profiles/${uid}`);
  if (privateData === null) {
    await reference.delete();
    return;
  }
  await reference.set(toPublicProfile(uid, privateData, now));
}

export async function syncCurrentPublicProfile(
  db: Firestore,
  uid: string,
  now: Timestamp,
): Promise<void> {
  if (!PATH_SEGMENT.test(uid)) invalid('uid: is invalid');
  const privateRef = db.doc(`users/${uid}`);
  const publicRef = db.doc(`public_profiles/${uid}`);
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(privateRef);
    if (!current.exists) {
      transaction.delete(publicRef);
      return;
    }
    transaction.set(publicRef, toPublicProfile(uid, current.data(), now));
  });
}

function database(): Firestore {
  const app = getApps()[0] ?? initializeApp();
  return getFirestore(app);
}

export const onUserChanged = onDocumentWritten(
  {document: 'users/{uid}', region: 'europe-west1'},
  async (event) => {
    const change = event.data;
    if (!change) return;
    try {
      await syncCurrentPublicProfile(
        database(),
        event.params.uid,
        Timestamp.fromDate(new Date(event.time)),
      );
    } catch (error) {
      if (!(error instanceof ProfileProjectionValidationError)) throw error;
      console.error('Skipping invalid user projection event', {
        uid: event.params.uid,
        message: error.message,
      });
    }
  },
);
