import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {
  GeoPoint,
  Query,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';

const PROJECT_ID = 'demo-gelatino';
const STORAGE_BUCKET = 'demo-gelatino.appspot.com';
const E2E_UIDS = ['e2e-alice', 'e2e-bob'] as const;

export const E2E_DOCUMENT_PATHS = [
  'users/e2e-alice',
  'users/e2e-bob',
  'public_profiles/e2e-alice',
  'public_profiles/e2e-bob',
  'places/e2e-place-1',
  'gelato_types/cono',
  'flavors/pistacchio',
  'flavors/stracciatella',
] as const;

export const E2E_STORAGE_PREFIXES = [
  'avatars/e2e-alice/',
  'avatars/e2e-bob/',
  'staging/e2e-alice/',
  'staging/e2e-bob/',
  'check_ins/e2e-alice/',
  'check_ins/e2e-bob/',
] as const;

export const E2E_RECURSIVE_ROOTS = [
  'users/e2e-alice',
  'users/e2e-bob',
  'feeds/e2e-alice',
  'feeds/e2e-bob',
  'friend_access/e2e-alice',
  'friend_access/e2e-bob',
] as const;

export const E2E_JOURNEY_CLEANUP_PATHS = [
  'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
  'friend_access/e2e-alice/members/e2e-bob',
  'friend_access/e2e-bob/members/e2e-alice',
  'users/e2e-alice/place_states/e2e-place-1',
  'users/e2e-bob/place_states/e2e-place-1',
] as const;

type SeedEnvironment = Record<string, string | undefined>;
type SeedDocument = Record<string, unknown>;

function projectIdFrom(environment: SeedEnvironment): string | undefined {
  if (environment.GCLOUD_PROJECT) return environment.GCLOUD_PROJECT;
  if (!environment.FIREBASE_CONFIG) return undefined;
  try {
    const config = JSON.parse(environment.FIREBASE_CONFIG) as {
      projectId?: string;
      project_id?: string;
    };
    return config.projectId ?? config.project_id;
  } catch {
    return undefined;
  }
}

function assertLocalHost(value: string | undefined, port: number, name: string) {
  const allowed = new Set([`127.0.0.1:${port}`, `localhost:${port}`]);
  if (!value || !allowed.has(value)) {
    throw new Error(`${name} must point to the local emulator on port ${port}`);
  }
}

export function assertE2ESeedEnvironment(environment: SeedEnvironment): void {
  if (projectIdFrom(environment) !== PROJECT_ID) {
    throw new Error(`E2E seed requires Firebase project ${PROJECT_ID}`);
  }
  assertLocalHost(environment.FIRESTORE_EMULATOR_HOST, 8080, 'Firestore');
  assertLocalHost(environment.FIREBASE_AUTH_EMULATOR_HOST, 9099, 'Auth');
  assertLocalHost(environment.FIREBASE_STORAGE_EMULATOR_HOST, 9199, 'Storage');
}

export function buildE2ESeedDocuments(
  now: Date,
): Record<(typeof E2E_DOCUMENT_PATHS)[number], SeedDocument> {
  const timestamp = Timestamp.fromDate(now);
  const privateProfile = (
    displayName: string,
    username: string,
    visibility: 'public' | 'friends',
    searchable: boolean,
  ): SeedDocument => ({
    display_name: displayName,
    username,
    bio: '',
    city: 'Milano',
    favorite_place_id: null,
    favorite_flavor_id: null,
    favorite_flavor_ids: [],
    profile_visibility: visibility,
    searchable,
    theme_mode: 'system',
    default_collection_view: 'list',
    reduced_motion: false,
    notifications_enabled: true,
    avatar_path: null,
    points: 0,
  });
  const publicProfile = (
    uid: string,
    displayName: string,
    username: string,
    visibility: 'public' | 'friends',
    searchable: boolean,
  ): SeedDocument => ({
    uid,
    display_name: displayName,
    display_name_lower: displayName.toLowerCase(),
    username,
    username_lower: username,
    avatar_path: null,
    bio: '',
    city: 'Milano',
    favorite_place_id: null,
    favorite_flavor_id: null,
    favorite_flavor_ids: [],
    profile_visibility: visibility,
    searchable,
    points: 0,
    updated_at: timestamp,
  });

  return {
    'users/e2e-alice': privateProfile('Alice E2E', 'alice', 'public', true),
    'users/e2e-bob': privateProfile('Bob E2E', 'bob', 'friends', false),
    'public_profiles/e2e-alice': publicProfile(
      'e2e-alice',
      'Alice E2E',
      'alice',
      'public',
      true,
    ),
    'public_profiles/e2e-bob': publicProfile(
      'e2e-bob',
      'Bob E2E',
      'bob',
      'friends',
      false,
    ),
    'places/e2e-place-1': {
      name: 'Gelateria E2E',
      address: 'Piazza del Duomo, Milano',
      location: new GeoPoint(45.4642, 9.19),
      geohash: 'u0nd9h',
      added_by_uid: 'e2e-alice',
      created_at: timestamp,
    },
    'gelato_types/cono': {name: 'Cono', sort_order: 0, is_active: true},
    'flavors/pistacchio': {
      name: 'Pistacchio',
      name_lower: 'pistacchio',
      color_hex: '#8FAF57',
      added_by_uid: 'e2e-alice',
      created_at: timestamp,
    },
    'flavors/stracciatella': {
      name: 'Stracciatella',
      name_lower: 'stracciatella',
      color_hex: '#EEE7DA',
      added_by_uid: 'e2e-alice',
      created_at: timestamp,
    },
  };
}

async function deleteAuthUser(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code !== 'auth/user-not-found') throw error;
  }
}

async function deleteQuery(query: Query): Promise<string[]> {
  const firestore = getFirestore();
  const snapshot = await query.get();
  for (const document of snapshot.docs) {
    await firestore.recursiveDelete(document.ref);
  }
  return snapshot.docs.map((document) => document.id);
}

async function queryIds(query: Query): Promise<string[]> {
  return (await query.get()).docs.map((document) => document.id);
}

async function waitForDeletedProjections(ids: readonly string[]): Promise<void> {
  if (ids.length === 0) return;
  const firestore = getFirestore();
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    const states = await firestore.getAll(
      ...ids.map((id) => firestore.doc(`check_in_projection_states/${id}`)),
    );
    if (states.every((state) => state.get('state') === 'deleted')) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Timed out waiting for E2E check-in projection cleanup');
}

async function cleanupE2EDocuments(): Promise<void> {
  const firestore = getFirestore();
  for (const path of E2E_RECURSIVE_ROOTS) {
    await firestore.recursiveDelete(firestore.doc(path));
  }

  const projectedIds = await queryIds(
    firestore
      .collection('check_in_projection_states')
      .where('author_uid', 'in', E2E_UIDS),
  );
  const artifactIds = new Set([
    ...projectedIds,
    ...(await queryIds(
      firestore
        .collection('check_in_accounting')
        .where('author_uid', 'in', E2E_UIDS),
    )),
    ...(await queryIds(
      firestore
        .collection('check_in_tombstones')
        .where('owner_uid', 'in', E2E_UIDS),
    )),
  ]);
  const checkInIds = await deleteQuery(
    firestore.collection('check_ins').where('user_id', 'in', E2E_UIDS),
  );
  checkInIds.forEach((id) => artifactIds.add(id));
  await waitForDeletedProjections(projectedIds);

  for (const checkInId of artifactIds) {
    await deleteQuery(
      firestore
        .collection('event_receipts')
        .where('check_in_id', '==', checkInId),
    );
  }
  for (const uid of E2E_UIDS) {
    await deleteQuery(
      firestore.collection('friendships').where(
        'member_uids',
        'array-contains',
        uid,
      ),
    );
    await deleteQuery(
      firestore.collection('pings').where('member_uids', 'array-contains', uid),
    );
  }

  const cleanup = firestore.batch();
  for (const path of [...E2E_DOCUMENT_PATHS, ...E2E_JOURNEY_CLEANUP_PATHS]) {
    cleanup.delete(firestore.doc(path));
  }
  cleanup.delete(firestore.doc('place_aggregates/e2e-place-1'));
  for (const checkInId of artifactIds) {
    for (const collection of [
      'check_in_accounting',
      'check_in_tombstones',
      'check_in_projection_states',
    ]) {
      cleanup.delete(firestore.doc(`${collection}/${checkInId}`));
    }
  }
  await cleanup.commit();
}

export async function seedE2E(environment = process.env): Promise<void> {
  assertE2ESeedEnvironment(environment);
  if (getApps().length === 0) {
    initializeApp({projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET});
  }

  await cleanupE2EDocuments();
  const bucket = getStorage().bucket(STORAGE_BUCKET);
  for (const prefix of E2E_STORAGE_PREFIXES) {
    await bucket.deleteFiles({prefix, force: true});
  }

  await Promise.all(E2E_UIDS.map((uid) => deleteAuthUser(uid)));
  const auth = getAuth();
  await auth.createUser({
    uid: 'e2e-alice',
    email: 'e2e-alice@example.test',
    password: 'gelatino-e2e-alice',
    displayName: 'Alice E2E',
    emailVerified: true,
  });
  await auth.createUser({
    uid: 'e2e-bob',
    email: 'e2e-bob@example.test',
    password: 'gelatino-e2e-bob',
    displayName: 'Bob E2E',
    emailVerified: true,
  });

  const firestore = getFirestore();
  const documents = buildE2ESeedDocuments(new Date('2026-01-02T03:04:05Z'));
  const writes = firestore.batch();
  for (const path of E2E_DOCUMENT_PATHS) {
    writes.set(firestore.doc(path), documents[path]);
  }
  await writes.commit();

}

if (require.main === module) {
  seedE2E()
    .then(() => console.log('E2E emulator seed complete.'))
    .catch((error: unknown) => {
      console.error(error instanceof Error ? error.message : error);
      process.exitCode = 1;
    });
}
