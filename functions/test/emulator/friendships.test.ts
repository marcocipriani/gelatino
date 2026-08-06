import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {FirebaseApp, deleteApp, initializeApp} from 'firebase/app';
import {
  Firestore,
  DocumentSnapshot,
  QuerySnapshot,
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  updateDoc,
} from 'firebase/firestore';
import {
  Functions,
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';
import {pairId} from '../../src/domain/ids';
import {
  PROJECT_ID,
  RulesHarness,
  createRulesHarness,
} from './helpers';

type FriendshipResult = {
  friendshipId: string;
  state: 'pending' | 'accepted' | 'declined' | 'removed';
  requesterUid: string;
  recipientUid: string;
};

type FriendshipCallables = {
  send(otherUid: string): Promise<FriendshipResult>;
  sendRaw(data: unknown): Promise<FriendshipResult>;
  respond(
    otherUid: string,
    response: 'accepted' | 'declined',
  ): Promise<FriendshipResult>;
  remove(otherUid: string): Promise<FriendshipResult>;
};

const aliceBobId = pairId('alice', 'bob');
const charlieAliceId = pairId('charlie', 'alice');

let harness: RulesHarness;
let unauthenticatedApp: FirebaseApp;
let alice: FriendshipCallables;
let bob: FriendshipCallables;
let charlie: FriendshipCallables;

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

function callables(app: FirebaseApp): FriendshipCallables {
  const functions = connectCallableFunctions(app);
  const send = httpsCallable<unknown, FriendshipResult>(
    functions,
    'sendFriendRequest',
  );
  const respond = httpsCallable<
    {otherUid: string; response: 'accepted' | 'declined'},
    FriendshipResult
  >(functions, 'respondToFriendRequest');
  const remove = httpsCallable<{otherUid: string}, FriendshipResult>(
    functions,
    'removeFriendship',
  );
  return {
    send: async (otherUid) => (await send({otherUid})).data,
    sendRaw: async (data) => (await send(data)).data,
    respond: async (otherUid, response) =>
      (await respond({otherUid, response})).data,
    remove: async (otherUid) => (await remove({otherUid})).data,
  };
}

async function assertCallableError(
  expectedCode: string,
  operation: () => Promise<unknown>,
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.equal(
      (error as {code?: string}).code,
      `functions/${expectedCode}`,
    );
    return true;
  });
}

async function adminGet(path: string) {
  let snapshot: DocumentSnapshot | undefined;
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    snapshot = await getDoc(
      doc(context.firestore() as unknown as Firestore, path),
    );
  });
  assert.ok(snapshot);
  return snapshot;
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

async function adminDelete(path: string): Promise<void> {
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(
      doc(context.firestore() as unknown as Firestore, path),
    );
  });
}

before(async () => {
  harness = await createRulesHarness();
  alice = callables(harness.storageUsers.alice.app);
  bob = callables(harness.storageUsers.bob.app);
  charlie = callables(harness.storageUsers.charlie.app);
  unauthenticatedApp = initializeApp(
    {
      apiKey: 'demo-key',
      appId: 'friendships-unauthenticated',
      authDomain: `${PROJECT_ID}.firebaseapp.com`,
      projectId: PROJECT_ID,
    },
    'friendships-unauthenticated',
  );
});

beforeEach(async () => {
  await harness.clearFirestore();
  await Promise.all([
    harness.seed('public_profiles/alice', {
      profile_visibility: 'friends',
      searchable: false,
    }),
    harness.seed('public_profiles/bob', {
      profile_visibility: 'friends',
      searchable: false,
    }),
    harness.seed('public_profiles/charlie', {
      profile_visibility: 'friends',
      searchable: false,
    }),
  ]);
});

after(async () => {
  await deleteApp(unauthenticatedApp);
  await harness.cleanup();
});

test('friendship callables enforce the reciprocal relationship lifecycle', async () => {
  const pending = await alice.send('bob');
  assert.deepEqual(pending, {
    friendshipId: aliceBobId,
    state: 'pending',
    requesterUid: 'alice',
    recipientUid: 'bob',
  });
  const initial = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  const initialRequestedAt = initial.get('requested_at') as Timestamp;
  assert.ok(initialRequestedAt instanceof Timestamp);

  assert.deepEqual(await alice.send('bob'), pending);
  const afterDuplicate = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  assert.ok(
    (afterDuplicate.get('requested_at') as Timestamp).isEqual(
      initialRequestedAt,
    ),
  );
  assert.deepEqual(await bob.send('alice'), pending);
  let allFriendships: QuerySnapshot | undefined;
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    allFriendships = await getDocs(
      collection(
        context.firestore() as unknown as Firestore,
        'friendships',
      ),
    );
  });
  assert.ok(allFriendships);
  assert.equal(
    allFriendships.docs.filter((snapshot) => snapshot.id === aliceBobId)
      .length,
    1,
  );

  await harness.seed(`friendships/${charlieAliceId}`, {
    member_uids: ['alice', 'charlie'],
    requester_uid: 'charlie',
    recipient_uid: 'alice',
    state: 'pending',
    requested_at: Timestamp.now(),
    responded_at: null,
    accepted_at: null,
    removed_at: null,
    affinity_score: 0,
    updated_at: Timestamp.now(),
  });
  await assertCallableError('permission-denied', () =>
    charlie.respond('alice', 'accepted'),
  );
  await assertCallableError('not-found', () =>
    charlie.respond('bob', 'accepted'),
  );
  await assertCallableError('permission-denied', () =>
    alice.respond('bob', 'accepted'),
  );

  assert.deepEqual(await bob.respond('alice', 'accepted'), {
    ...pending,
    state: 'accepted',
  });
  const accepted = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  const acceptedAt = accepted.get('accepted_at') as Timestamp;
  const acceptedUpdatedAt = accepted.get('updated_at') as Timestamp;
  assert.ok(acceptedAt instanceof Timestamp);
  const [aliceToBob, bobToAlice] = await Promise.all([
    adminGet('friend_access/alice/members/bob'),
    adminGet('friend_access/bob/members/alice'),
  ]);
  assert.equal(aliceToBob.get('friendship_id'), aliceBobId);
  assert.equal(bobToAlice.get('friendship_id'), aliceBobId);
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'public_profiles/bob')),
  );
  await assertSucceeds(
    getDoc(doc(harness.bobDb, 'public_profiles/alice')),
  );
  assert.deepEqual(await alice.send('bob'), {
    ...pending,
    state: 'accepted',
  });

  assert.deepEqual(await bob.respond('alice', 'accepted'), {
    ...pending,
    state: 'accepted',
  });
  const afterRepeatedAccept = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  assert.ok(
    (afterRepeatedAccept.get('accepted_at') as Timestamp).isEqual(
      acceptedAt,
    ),
  );
  assert.ok(
    (afterRepeatedAccept.get('updated_at') as Timestamp).isEqual(
      acceptedUpdatedAt,
    ),
  );

  await adminUpdate(`friendships/${aliceBobId}`, {affinity_score: 17});
  assert.deepEqual(await alice.remove('bob'), {
    ...pending,
    state: 'removed',
  });
  const [removedAliceToBob, removedBobToAlice] = await Promise.all([
    adminGet('friend_access/alice/members/bob'),
    adminGet('friend_access/bob/members/alice'),
  ]);
  assert.equal(removedAliceToBob.exists(), false);
  assert.equal(removedBobToAlice.exists(), false);
  await assertFails(
    getDoc(doc(harness.aliceDb, 'public_profiles/bob')),
  );
  await assertFails(
    getDoc(doc(harness.bobDb, 'public_profiles/alice')),
  );

  assert.deepEqual(await alice.send('bob'), pending);
  const reopened = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  assert.ok(
    (reopened.get('requested_at') as Timestamp).toMillis() >
      initialRequestedAt.toMillis(),
  );
  assert.equal(reopened.get('responded_at'), null);
  assert.equal(reopened.get('accepted_at'), null);
  assert.equal(reopened.get('removed_at'), null);
  assert.equal(reopened.get('affinity_score'), 17);

  assert.deepEqual(await bob.respond('alice', 'declined'), {
    ...pending,
    state: 'declined',
  });
  const declined = await getDoc(
    doc(harness.aliceDb, 'friendships', aliceBobId),
  );
  assert.ok(declined.get('responded_at') instanceof Timestamp);
  assert.equal(declined.get('accepted_at'), null);
  assert.equal(declined.get('removed_at'), null);
  await assertCallableError('failed-precondition', () =>
    bob.respond('alice', 'accepted'),
  );
  await assertCallableError('failed-precondition', () =>
    alice.remove('bob'),
  );
});

test('friendship callables reject self-targets and unauthenticated callers', async () => {
  await assertCallableError('invalid-argument', () => alice.send('alice'));
  const unauthenticated = callables(unauthenticatedApp);
  await assertCallableError('unauthenticated', () =>
    unauthenticated.send('bob'),
  );
});

test('friendship callables reject malformed path-unsafe UIDs', async () => {
  for (const data of [
    {otherUid: 'bad/uid'},
    {otherUid: ''},
    {otherUid: 42},
    {otherUid: 'x'.repeat(129)},
  ]) {
    await assertCallableError('invalid-argument', () =>
      alice.sendRaw(data),
    );
  }
});

test('every friendship operation requires the other public profile', async () => {
  await alice.send('bob');
  await adminDelete('public_profiles/bob');
  await assertCallableError('not-found', () => alice.send('bob'));

  await harness.seed('public_profiles/bob', {
    profile_visibility: 'friends',
    searchable: false,
  });
  await bob.respond('alice', 'accepted');
  await adminDelete('public_profiles/alice');
  await assertCallableError('not-found', () =>
    bob.respond('alice', 'accepted'),
  );
  await assertCallableError('not-found', () => bob.remove('alice'));
});
