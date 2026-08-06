import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails} from '@firebase/rules-unit-testing';
import {FirebaseApp, deleteApp, initializeApp} from 'firebase/app';
import {
  DocumentSnapshot,
  Firestore,
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import {
  Functions,
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';
import {ref, uploadBytes} from 'firebase/storage';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {getStorage as getAdminStorage} from 'firebase-admin/storage';
import {pairId, permanentPhotoPath, stagingPhotoPath} from '../../src/domain/ids';
import {publishCheckIn} from '../../src/services/check_ins';
import {
  PROJECT_ID,
  RulesHarness,
  STORAGE_BUCKET,
  createRulesHarness,
} from './helpers';

type CheckInResult = {
  checkInId: string;
  status: 'created' | 'existing' | 'deleted' | 'already-deleted';
};

type CheckInCallables = {
  create(data: unknown): Promise<CheckInResult>;
  delete(checkInId: string): Promise<CheckInResult>;
};

type CreatePayload = {
  checkInId: string;
  placeId: string;
  gelatoTypeId: string;
  flavorIds: string[];
  rating: number;
  reviewText: string;
  taggedUserIds: string[];
  stagingObjectPath: string;
};

const CHECK_IN_ID = 'ABCDEFGHIJKLMNOPQRST';
const CANONICAL_ONLY_ID = 'BCDEFGHIJKLMNOPQRSTU';
const ACCOUNTING_ONLY_ID = 'CDEFGHIJKLMNOPQRSTUV';
const CORRUPT_ACCOUNTING_ID = 'DEFGHIJKLMNOPQRSTUVW';
const MISSING_PLACE_ID = 'EFGHIJKLMNOPQRSTUVWX';
const MISSING_TYPE_ID = 'FGHIJKLMNOPQRSTUVWXY';
const MISSING_FLAVOR_ID = 'GHIJKLMNOPQRSTUVWXYZ';
const CHARLIE_TAG_ID = 'HIJKLMNOPQRSTUVWXYZa';
const FOREIGN_STAGING_ID = 'IJKLMNOPQRSTUVWXYZab';
const MISSING_STAGING_ID = 'JKLMNOPQRSTUVWXYZabc';
const CONCURRENT_RETRY_ID = 'KLMNOPQRSTUVWXYZabcd';
const ABA_RACE_ID = 'LMNOPQRSTUVWXYZabcde';
const OVERFLOW_POINTS_ID = 'MNOPQRSTUVWXYZabcdef';
const OVERFLOW_VISITS_ID = 'NOPQRSTUVWXYZabcdefg';
const OVERFLOW_AFFINITY_ID = 'OPQRSTUVWXYZabcdefgh';
const BAD_MIME_ID = 'PQRSTUVWXYZabcdefghi';
const OVERSIZE_ID = 'QRSTUVWXYZabcdefghij';
const INVALID_TOMBSTONE_ID = 'RSTUVWXYZabcdefghijk';
const EMPTY_USERNAME_ID = 'STUVWXYZabcdefghijkl';
const aliceBobId = pairId('alice', 'bob');

const mediaIds = [
  CHECK_IN_ID,
  CANONICAL_ONLY_ID,
  ACCOUNTING_ONLY_ID,
  CORRUPT_ACCOUNTING_ID,
  MISSING_PLACE_ID,
  MISSING_TYPE_ID,
  MISSING_FLAVOR_ID,
  CHARLIE_TAG_ID,
  FOREIGN_STAGING_ID,
  MISSING_STAGING_ID,
  CONCURRENT_RETRY_ID,
  ABA_RACE_ID,
  OVERFLOW_POINTS_ID,
  OVERFLOW_VISITS_ID,
  OVERFLOW_AFFINITY_ID,
  BAD_MIME_ID,
  OVERSIZE_ID,
  INVALID_TOMBSTONE_ID,
  EMPTY_USERNAME_ID,
];

let harness: RulesHarness;
let unauthenticatedApp: FirebaseApp;
let alice: CheckInCallables;
let bob: CheckInCallables;
let charlie: CheckInCallables;

function emulatorAddress(value: string | undefined, fallbackPort: number) {
  const address = value ?? `127.0.0.1:${fallbackPort}`;
  const separator = address.lastIndexOf(':');
  if (separator < 1) throw new Error(`Invalid emulator address: ${address}`);
  return {
    host: address.slice(0, separator),
    port: Number(address.slice(separator + 1)),
  };
}

function connectCallableFunctions(app: FirebaseApp): Functions {
  const functions = getFunctions(app, 'europe-west1');
  const address = emulatorAddress(
    process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST,
    5001,
  );
  connectFunctionsEmulator(functions, address.host, address.port);
  return functions;
}

function callables(app: FirebaseApp): CheckInCallables {
  const functions = connectCallableFunctions(app);
  const create = httpsCallable<unknown, CheckInResult>(
    functions,
    'createCheckIn',
  );
  const remove = httpsCallable<{checkInId: string}, CheckInResult>(
    functions,
    'deleteCheckIn',
  );
  return {
    create: async (data) => (await create(data)).data,
    delete: async (checkInId) => (await remove({checkInId})).data,
  };
}

function payload(
  checkInId = CHECK_IN_ID,
  overrides: Partial<CreatePayload> = {},
): CreatePayload {
  return {
    checkInId,
    placeId: 'place-1',
    gelatoTypeId: 'cono',
    flavorIds: ['pistacchio'],
    rating: 5,
    reviewText: '  Delizioso  ',
    taggedUserIds: ['bob'],
    stagingObjectPath: stagingPhotoPath('alice', checkInId),
    ...overrides,
  };
}

async function assertCallableError(
  expectedCode: string,
  operation: () => Promise<unknown>,
  expectedReason?: string,
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.equal(
      (error as {code?: string}).code,
      `functions/${expectedCode}`,
    );
    if (expectedReason !== undefined) {
      const details = (error as {details?: unknown}).details as
        | {reason?: string}
        | undefined;
      assert.equal(details?.reason, expectedReason);
    }
    return true;
  });
}

async function assertServiceError(
  expectedCode: string,
  operation: () => Promise<unknown>,
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.equal((error as {code?: string}).code, expectedCode);
    return true;
  });
}

async function adminGet(path: string): Promise<DocumentSnapshot> {
  let snapshot: DocumentSnapshot | undefined;
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    snapshot = await getDoc(
      doc(context.firestore() as unknown as Firestore, path),
    );
  });
  assert.ok(snapshot);
  return snapshot;
}

async function adminDelete(path: string): Promise<void> {
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore() as unknown as Firestore, path));
  });
}

async function adminUpdate(
  path: string,
  data: Record<string, unknown>,
): Promise<void> {
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore() as unknown as Firestore, path),
      data,
    );
  });
}

async function uploadAliceStaging(checkInId: string): Promise<void> {
  await uploadBytes(
    ref(
      harness.storageUsers.alice.storage,
      stagingPhotoPath('alice', checkInId),
    ),
    new Uint8Array([0xff, 0xd8, 0xff, 0xd9]),
    {
      contentType: 'image/jpeg',
      customMetadata: {firebaseStorageDownloadTokens: 'staging-token'},
    },
  );
}

async function seedBaseline(): Promise<void> {
  const now = Timestamp.now();
  await Promise.all([
    harness.seed('users/alice', {
      display_name: 'Alice',
      username: 'alice-gelato',
      avatar_path: 'avatars/alice/profile.jpg',
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('users/bob', {
      display_name: 'Bob',
      username: 'bob-gelato',
      avatar_path: null,
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('users/charlie', {
      display_name: 'Charlie',
      username: 'charlie-gelato',
      avatar_path: null,
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('public_profiles/alice', {
      display_name: 'Alice',
      username: 'alice-gelato',
      avatar_path: 'avatars/alice/profile.jpg',
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('public_profiles/bob', {
      display_name: 'Bob',
      username: 'bob-gelato',
      avatar_path: null,
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('public_profiles/charlie', {
      display_name: 'Charlie',
      username: 'charlie-gelato',
      avatar_path: null,
      profile_visibility: 'friends',
      searchable: false,
      points: 0,
    }),
    harness.seed('places/place-1', {
      name: 'Gelateria Uno',
      address: 'Via Roma 1',
    }),
    harness.seed('gelato_types/cono', {name: 'Cono'}),
    harness.seed('flavors/pistacchio', {name: 'Pistacchio'}),
    harness.seed(`friendships/${aliceBobId}`, {
      member_uids: ['alice', 'bob'],
      requester_uid: 'alice',
      recipient_uid: 'bob',
      state: 'accepted',
      affinity_score: 0,
      requested_at: now,
      responded_at: now,
      accepted_at: now,
      removed_at: null,
      updated_at: now,
    }),
    harness.seed('friend_access/alice/members/bob', {
      friendship_id: aliceBobId,
    }),
    harness.seed('friend_access/bob/members/alice', {
      friendship_id: aliceBobId,
    }),
  ]);
}

async function waitForProjectedUsername(
  uid: string,
  expected: string,
): Promise<void> {
  for (let attempt = 0; attempt < 100; attempt++) {
    const snapshot = await adminGet(`public_profiles/${uid}`);
    if (snapshot.get('username') === expected) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.fail(`public_profiles/${uid}.username never became "${expected}"`);
}

async function assertAwardedState(
  alicePoints: number,
  bobPoints: number,
  visitCount: number,
  affinity: number,
): Promise<void> {
  const [aliceUser, bobUser, aliceVisits, bobVisits, friendship] =
    await Promise.all([
      adminGet('users/alice'),
      adminGet('users/bob'),
      adminGet('users/alice/place_visit_stats/place-1'),
      adminGet('users/bob/place_visit_stats/place-1'),
      adminGet(`friendships/${aliceBobId}`),
    ]);
  assert.equal(aliceUser.get('points'), alicePoints);
  assert.equal(bobUser.get('points'), bobPoints);
  assert.equal(aliceVisits.get('count'), visitCount);
  assert.equal(bobVisits.get('count'), visitCount);
  assert.equal(friendship.get('affinity_score'), affinity);
}

before(async () => {
  harness = await createRulesHarness();
  alice = callables(harness.storageUsers.alice.app);
  bob = callables(harness.storageUsers.bob.app);
  charlie = callables(harness.storageUsers.charlie.app);
  unauthenticatedApp = initializeApp(
    {
      apiKey: 'demo-key',
      appId: 'check-ins-unauthenticated',
      authDomain: `${PROJECT_ID}.firebaseapp.com`,
      projectId: PROJECT_ID,
    },
    'check-ins-unauthenticated',
  );
});

beforeEach(async () => {
  await harness.clearFirestore();
  await Promise.all(
    mediaIds.flatMap((checkInId) => [
      harness.deleteStorage(stagingPhotoPath('alice', checkInId)),
      harness.deleteStorage(stagingPhotoPath('bob', checkInId)),
      harness.deleteStorage(permanentPhotoPath('alice', checkInId, 1)),
      harness.deleteStorage(permanentPhotoPath('bob', checkInId, 1)),
    ]),
  );
  await seedBaseline();
});

after(async () => {
  await deleteApp(unauthenticatedApp);
  await harness.cleanup();
});

test('publication and deletion are exact-once across retries', async () => {
  await uploadAliceStaging(CHECK_IN_ID);

  assert.deepEqual(await alice.create(payload()), {
    checkInId: CHECK_IN_ID,
    status: 'created',
  });

  const canonical = await adminGet(`check_ins/${CHECK_IN_ID}`);
  assert.deepEqual(canonical.get('user_snapshot'), {
    display_name: 'Alice',
    username: 'alice-gelato',
    avatar_path: 'avatars/alice/profile.jpg',
  });
  assert.deepEqual(canonical.get('place_snapshot'), {
    name: 'Gelateria Uno',
    address: 'Via Roma 1',
  });
  assert.deepEqual(canonical.get('gelato_type'), {
    id: 'cono',
    name: 'Cono',
  });
  assert.deepEqual(canonical.get('flavors'), [
    {id: 'pistacchio', name: 'Pistacchio', color_hex: null},
  ]);
  assert.equal(canonical.get('user_id'), 'alice');
  assert.equal(canonical.get('place_id'), 'place-1');
  assert.equal(canonical.get('rating'), 5);
  assert.equal(canonical.get('review_text'), 'Delizioso');
  assert.deepEqual(canonical.get('tagged_user_ids'), ['bob']);
  assert.equal(
    canonical.get('photo_storage_path'),
    permanentPhotoPath('alice', CHECK_IN_ID, 1),
  );
  assert.ok(canonical.get('created_at') instanceof Timestamp);
  assert.ok(canonical.get('updated_at') instanceof Timestamp);
  assert.equal(canonical.get('schema_version'), 2);

  const accounting = await adminGet(`check_in_accounting/${CHECK_IN_ID}`);
  assert.equal(accounting.get('author_uid'), 'alice');
  assert.equal(accounting.get('place_id'), 'place-1');
  assert.deepEqual(accounting.get('awarded_points'), [
    {uid: 'alice', points: 25},
    {uid: 'bob', points: 25},
  ]);
  assert.deepEqual(accounting.get('visit_count_deltas'), [
    {uid: 'alice', delta: 1},
    {uid: 'bob', delta: 1},
  ]);
  assert.deepEqual(accounting.get('friendship_affinity_deltas'), [
    {friendship_id: aliceBobId, delta: 1},
  ]);
  assert.ok(accounting.get('created_at') instanceof Timestamp);
  assert.equal(accounting.get('schema_version'), 1);

  assert.equal(
    await harness.storageExists(permanentPhotoPath('alice', CHECK_IN_ID, 1)),
    true,
  );
  const permanentMetadata = await harness.storageMetadata(
    permanentPhotoPath('alice', CHECK_IN_ID, 1),
  );
  assert.equal(permanentMetadata.contentType, 'image/jpeg');
  assert.equal(
    Boolean(permanentMetadata.metadata?.firebaseStorageDownloadTokens),
    false,
  );
  assert.equal(
    await harness.storageExists(stagingPhotoPath('alice', CHECK_IN_ID)),
    false,
  );
  await assertAwardedState(25, 25, 1, 1);

  assert.deepEqual(await alice.create(payload()), {
    checkInId: CHECK_IN_ID,
    status: 'existing',
  });
  await assertAwardedState(25, 25, 1, 1);

  await assertCallableError('permission-denied', () =>
    bob.create(
      payload(CHECK_IN_ID, {
        taggedUserIds: [],
        stagingObjectPath: stagingPhotoPath('bob', CHECK_IN_ID),
      }),
    ),
  );
  await assertCallableError('permission-denied', () => bob.delete(CHECK_IN_ID));
  await assertCallableError('permission-denied', () =>
    charlie.delete(CHECK_IN_ID),
  );

  assert.deepEqual(await alice.delete(CHECK_IN_ID), {
    checkInId: CHECK_IN_ID,
    status: 'deleted',
  });
  assert.equal((await adminGet(`check_ins/${CHECK_IN_ID}`)).exists(), false);
  assert.equal(
    (await adminGet(`check_in_accounting/${CHECK_IN_ID}`)).exists(),
    false,
  );
  const tombstone = await adminGet(`check_in_tombstones/${CHECK_IN_ID}`);
  assert.equal(tombstone.get('owner_uid'), 'alice');
  assert.ok(tombstone.get('deleted_at') instanceof Timestamp);
  assert.equal(tombstone.get('schema_version'), 1);
  await assertAwardedState(0, 0, 0, 0);

  assert.deepEqual(await alice.delete(CHECK_IN_ID), {
    checkInId: CHECK_IN_ID,
    status: 'already-deleted',
  });
  await assertAwardedState(0, 0, 0, 0);
});

test('a concurrent retry resolves existing when staging disappears', async () => {
  await uploadAliceStaging(CONCURRENT_RETRY_ID);
  const stagingPath = stagingPhotoPath('alice', CONCURRENT_RETRY_ID);
  const realBucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const realStagingFile = realBucket.file(stagingPath);
  let unblockMetadata = () => {};
  const metadataGate = new Promise<void>((resolve) => {
    unblockMetadata = resolve;
  });
  let signalMetadataReached = () => {};
  const metadataReached = new Promise<void>((resolve) => {
    signalMetadataReached = resolve;
  });
  const blockedStagingFile = new Proxy(realStagingFile, {
    get(target, property, receiver) {
      if (property === 'getMetadata') {
        return async () => {
          signalMetadataReached();
          await metadataGate;
          return target.getMetadata();
        };
      }
      const value = Reflect.get(target, property, receiver);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  const blockedBucket = new Proxy(realBucket, {
    get(target, property, receiver) {
      if (property === 'file') {
        return (path: string) =>
          path === stagingPath ? blockedStagingFile : target.file(path);
      }
      const value = Reflect.get(target, property, receiver);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });

  const concurrentRetry = publishCheckIn(
    getAdminFirestore(harness.adminApp),
    blockedBucket,
    'alice',
    payload(CONCURRENT_RETRY_ID),
  );
  await metadataReached;
  assert.deepEqual(
    await alice.create(payload(CONCURRENT_RETRY_ID)),
    {checkInId: CONCURRENT_RETRY_ID, status: 'created'},
  );
  unblockMetadata();
  assert.deepEqual(await concurrentRetry, {
    checkInId: CONCURRENT_RETRY_ID,
    status: 'existing',
  });
  await assertAwardedState(25, 25, 1, 1);
});

test('a deleted ID cannot be recreated by a pre-delete publication', async () => {
  await uploadAliceStaging(ABA_RACE_ID);
  const stagingPath = stagingPhotoPath('alice', ABA_RACE_ID);
  const realBucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const realStagingFile = realBucket.file(stagingPath);
  let unblockCopy = () => {};
  const copyGate = new Promise<void>((resolve) => {
    unblockCopy = resolve;
  });
  let signalCopyFinished = () => {};
  const copyFinished = new Promise<void>((resolve) => {
    signalCopyFinished = resolve;
  });
  const blockedStagingFile = new Proxy(realStagingFile, {
    get(target, property, receiver) {
      if (property === 'copy') {
        return async (...args: Parameters<typeof target.copy>) => {
          const result = await target.copy(...args);
          signalCopyFinished();
          await copyGate;
          return result;
        };
      }
      const value = Reflect.get(target, property, receiver);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  const blockedBucket = new Proxy(realBucket, {
    get(target, property, receiver) {
      if (property === 'file') {
        return (path: string) =>
          path === stagingPath ? blockedStagingFile : target.file(path);
      }
      const value = Reflect.get(target, property, receiver);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });

  const pausedPublication = publishCheckIn(
    getAdminFirestore(harness.adminApp),
    blockedBucket,
    'alice',
    payload(ABA_RACE_ID),
  );
  await copyFinished;
  assert.deepEqual(await alice.create(payload(ABA_RACE_ID)), {
    checkInId: ABA_RACE_ID,
    status: 'created',
  });
  assert.deepEqual(await alice.delete(ABA_RACE_ID), {
    checkInId: ABA_RACE_ID,
    status: 'deleted',
  });
  unblockCopy();

  await assertServiceError('failed-precondition', () => pausedPublication);
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(ABA_RACE_ID)),
  );
  await assertCallableError('permission-denied', () =>
    bob.delete(ABA_RACE_ID),
  );
  assert.deepEqual(await alice.delete(ABA_RACE_ID), {
    checkInId: ABA_RACE_ID,
    status: 'already-deleted',
  });
  assert.equal((await adminGet(`check_ins/${ABA_RACE_ID}`)).exists(), false);
  assert.equal(
    (await adminGet(`check_in_accounting/${ABA_RACE_ID}`)).exists(),
    false,
  );
  const tombstone = await adminGet(`check_in_tombstones/${ABA_RACE_ID}`);
  assert.equal(tombstone.get('owner_uid'), 'alice');
  assert.ok(tombstone.get('deleted_at') instanceof Timestamp);
  assert.equal(tombstone.get('schema_version'), 1);
  await assertAwardedState(0, 0, 0, 0);

  await assertFails(
    setDoc(doc(harness.aliceDb, 'check_in_tombstones/client-write'), {
      owner_uid: 'alice',
      deleted_at: Timestamp.now(),
      schema_version: 1,
    }),
  );
  await assertFails(
    getDoc(doc(harness.aliceDb, 'check_in_tombstones', ABA_RACE_ID)),
  );
});

test('publication validates an existing tombstone before media', async () => {
  await harness.seed(`check_in_tombstones/${INVALID_TOMBSTONE_ID}`, {
    owner_uid: 42,
    deleted_at: Timestamp.now(),
    schema_version: 1,
  });
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(INVALID_TOMBSTONE_ID)),
  );
  await harness.seed(`check_in_tombstones/${INVALID_TOMBSTONE_ID}`, {
    owner_uid: 'alice',
    deleted_at: Timestamp.now(),
    schema_version: 2,
  });
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(INVALID_TOMBSTONE_ID)),
  );
});

test('publication rejects unsafe counter additions atomically', async () => {
  await uploadAliceStaging(OVERFLOW_POINTS_ID);
  await adminUpdate('users/alice', {points: Number.MAX_SAFE_INTEGER});
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(OVERFLOW_POINTS_ID, {taggedUserIds: []})),
  );
  assert.equal(
    (await adminGet('users/alice')).get('points'),
    Number.MAX_SAFE_INTEGER,
  );
  assert.equal(
    (await adminGet(`check_ins/${OVERFLOW_POINTS_ID}`)).exists(),
    false,
  );

  await adminUpdate('users/alice', {points: 0});
  await harness.seed('users/alice/place_visit_stats/place-1', {
    count: Number.MAX_SAFE_INTEGER,
  });
  await uploadAliceStaging(OVERFLOW_VISITS_ID);
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(OVERFLOW_VISITS_ID, {taggedUserIds: []})),
  );
  assert.equal((await adminGet('users/alice')).get('points'), 0);
  assert.equal(
    (await adminGet('users/alice/place_visit_stats/place-1')).get('count'),
    Number.MAX_SAFE_INTEGER,
  );
  assert.equal(
    (await adminGet(`check_ins/${OVERFLOW_VISITS_ID}`)).exists(),
    false,
  );

  await adminDelete('users/alice/place_visit_stats/place-1');
  await adminUpdate(`friendships/${aliceBobId}`, {
    affinity_score: Number.MAX_SAFE_INTEGER,
  });
  await uploadAliceStaging(OVERFLOW_AFFINITY_ID);
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(OVERFLOW_AFFINITY_ID)),
  );
  assert.equal((await adminGet('users/alice')).get('points'), 0);
  assert.equal((await adminGet('users/bob')).get('points'), 0);
  assert.equal(
    (await adminGet(`friendships/${aliceBobId}`)).get('affinity_score'),
    Number.MAX_SAFE_INTEGER,
  );
  assert.equal(
    (await adminGet(`check_ins/${OVERFLOW_AFFINITY_ID}`)).exists(),
    false,
  );
});

test('publication rejects invalid staging metadata before copy', async () => {
  await harness.seedStorage(
    stagingPhotoPath('alice', BAD_MIME_ID),
    new Uint8Array([1, 2, 3]),
    'image/png',
  );
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(BAD_MIME_ID)),
  );
  assert.equal(
    await harness.storageExists(permanentPhotoPath('alice', BAD_MIME_ID, 1)),
    false,
  );

  await harness.seedStorage(
    stagingPhotoPath('alice', OVERSIZE_ID),
    new Uint8Array(5 * 1024 * 1024 + 1),
    'image/jpeg',
  );
  await assertCallableError('failed-precondition', () =>
    alice.create(payload(OVERSIZE_ID)),
  );
  assert.equal(
    await harness.storageExists(permanentPhotoPath('alice', OVERSIZE_ID, 1)),
    false,
  );
});

test('publication rejects missing catalog entries before reading media', async () => {
  await adminDelete('places/place-1');
  await assertCallableError(
    'not-found',
    () => alice.create(payload(MISSING_PLACE_ID)),
    'place_missing',
  );
  await harness.seed('places/place-1', {
    name: 'Gelateria Uno',
    address: 'Via Roma 1',
  });

  await adminDelete('gelato_types/cono');
  await assertCallableError(
    'not-found',
    () => alice.create(payload(MISSING_TYPE_ID)),
    'gelato_type_missing',
  );
  await harness.seed('gelato_types/cono', {name: 'Cono'});

  await adminDelete('flavors/pistacchio');
  await assertCallableError(
    'not-found',
    () => alice.create(payload(MISSING_FLAVOR_ID)),
    'flavor_missing',
  );
  await harness.seed('flavors/pistacchio', {name: 'Pistacchio'});

  await adminDelete('public_profiles/alice');
  await assertCallableError(
    'not-found',
    () => alice.create(payload(MISSING_FLAVOR_ID)),
    'profile_missing',
  );
});

test('publication accepts a profile that never set a username', async () => {
  // The app creates every account with username: '' and never writes one.
  await adminUpdate('users/alice', {username: ''});
  await waitForProjectedUsername('alice', '');
  await uploadAliceStaging(EMPTY_USERNAME_ID);
  assert.deepEqual(
    await alice.create(payload(EMPTY_USERNAME_ID, {taggedUserIds: []})),
    {checkInId: EMPTY_USERNAME_ID, status: 'created'},
  );
  const canonical = await adminGet(`check_ins/${EMPTY_USERNAME_ID}`);
  assert.equal(canonical.get('user_snapshot').username, '');
});

test('publication rejects non-friends and invalid staging ownership', async () => {
  await assertCallableError(
    'failed-precondition',
    () => alice.create(payload(CHARLIE_TAG_ID, {taggedUserIds: ['charlie']})),
    'friend_missing',
  );
  await assertCallableError(
    'permission-denied',
    () =>
      alice.create(
        payload(FOREIGN_STAGING_ID, {
          stagingObjectPath: stagingPhotoPath('bob', FOREIGN_STAGING_ID),
        }),
      ),
    'foreign_photo',
  );
  await assertCallableError(
    'not-found',
    () => alice.create(payload(MISSING_STAGING_ID)),
    'photo_missing',
  );
});

test('publication maps malformed payloads to invalid-argument', async () => {
  await assertCallableError('invalid-argument', () =>
    alice.create(payload(CHECK_IN_ID, {rating: 0})),
  );
  await assertCallableError('invalid-argument', () =>
    alice.create(
      payload(CHECK_IN_ID, {
        flavorIds: ['a', 'b', 'c', 'd', 'e'],
      }),
    ),
  );
  await assertCallableError('invalid-argument', () =>
    alice.create(payload(CHECK_IN_ID, {reviewText: 'x'.repeat(501)})),
  );
  await assertCallableError('invalid-argument', () =>
    alice.create({...payload(), stagingObjectPath: 42}),
  );
});

test('check-in callables require authentication', async () => {
  const unauthenticated = callables(unauthenticatedApp);
  await assertCallableError('unauthenticated', () =>
    unauthenticated.create(payload()),
  );
  await assertCallableError('unauthenticated', () =>
    unauthenticated.delete(CHECK_IN_ID),
  );
});

test('delete rejects a canonical-only pair without reversing awards', async () => {
  await uploadAliceStaging(CANONICAL_ONLY_ID);
  await alice.create(
    payload(CANONICAL_ONLY_ID, {taggedUserIds: []}),
  );
  await adminDelete(`check_in_accounting/${CANONICAL_ONLY_ID}`);

  await assertCallableError('failed-precondition', () =>
    bob.delete(CANONICAL_ONLY_ID),
  );
  await assertCallableError('failed-precondition', () =>
    alice.delete(CANONICAL_ONLY_ID),
  );
  assert.equal(
    (await adminGet(`check_ins/${CANONICAL_ONLY_ID}`)).exists(),
    true,
  );
  assert.equal((await adminGet('users/alice')).get('points'), 20);
  assert.equal(
    (await adminGet('users/alice/place_visit_stats/place-1')).get('count'),
    1,
  );
});

test('delete rejects an accounting-only pair without reversing awards', async () => {
  await uploadAliceStaging(ACCOUNTING_ONLY_ID);
  await alice.create(
    payload(ACCOUNTING_ONLY_ID, {taggedUserIds: []}),
  );
  await adminDelete(`check_ins/${ACCOUNTING_ONLY_ID}`);

  await assertCallableError('failed-precondition', () =>
    charlie.delete(ACCOUNTING_ONLY_ID),
  );
  await assertCallableError('failed-precondition', () =>
    alice.delete(ACCOUNTING_ONLY_ID),
  );
  assert.equal(
    (await adminGet(`check_in_accounting/${ACCOUNTING_ONLY_ID}`)).exists(),
    true,
  );
  assert.equal((await adminGet('users/alice')).get('points'), 20);
  assert.equal(
    (await adminGet('users/alice/place_visit_stats/place-1')).get('count'),
    1,
  );
});

test('delete validates every accounting delta before reversing any', async () => {
  await uploadAliceStaging(CORRUPT_ACCOUNTING_ID);
  await alice.create(payload(CORRUPT_ACCOUNTING_ID));
  await adminUpdate(`check_in_accounting/${CORRUPT_ACCOUNTING_ID}`, {
    awarded_points: [
      {uid: 'alice', points: 25},
      {uid: 'bob', points: 24},
    ],
  });

  await assertCallableError('failed-precondition', () =>
    alice.delete(CORRUPT_ACCOUNTING_ID),
  );
  assert.equal(
    (await adminGet(`check_ins/${CORRUPT_ACCOUNTING_ID}`)).exists(),
    true,
  );
  assert.equal(
    (await adminGet(`check_in_accounting/${CORRUPT_ACCOUNTING_ID}`)).exists(),
    true,
  );
  await assertAwardedState(25, 25, 1, 1);
});

test('delete rejects valid deltas that target non-canonical participants', async () => {
  await uploadAliceStaging(CORRUPT_ACCOUNTING_ID);
  await alice.create(payload(CORRUPT_ACCOUNTING_ID));
  await adminUpdate(`check_in_accounting/${CORRUPT_ACCOUNTING_ID}`, {
    awarded_points: [
      {uid: 'alice', points: 25},
      {uid: 'charlie', points: 25},
    ],
    visit_count_deltas: [
      {uid: 'alice', delta: 1},
      {uid: 'charlie', delta: 1},
    ],
  });

  await assertCallableError('failed-precondition', () =>
    alice.delete(CORRUPT_ACCOUNTING_ID),
  );
  assert.equal(
    (await adminGet(`check_ins/${CORRUPT_ACCOUNTING_ID}`)).exists(),
    true,
  );
  assert.equal(
    (await adminGet(`check_in_accounting/${CORRUPT_ACCOUNTING_ID}`)).exists(),
    true,
  );
  await assertAwardedState(25, 25, 1, 1);
  assert.equal((await adminGet('users/charlie')).get('points'), 0);
});
