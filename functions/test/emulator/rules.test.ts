import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  GeoPoint,
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} from 'firebase/storage';
import {RulesHarness, createRulesHarness} from './helpers';

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const CHECK_IN_ID = 'ABCDEFGHIJKLMNOPQRST';

let harness: RulesHarness;

before(async () => {
  harness = await createRulesHarness();
});

beforeEach(async () => {
  await harness.clearFirestore();
});

after(async () => {
  await harness.cleanup();
});

test('private user and feed paths are owner-only', async () => {
  await harness.seed('users/alice', {display_name: 'Alice', points: 10});
  await harness.seed('feeds/alice/items/c1', {author_uid: 'bob'});
  await assertSucceeds(getDoc(doc(harness.aliceDb, 'users/alice')));
  await assertFails(getDoc(doc(harness.bobDb, 'users/alice')));
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'feeds/alice/items/c1')),
  );
  await assertFails(getDoc(doc(harness.bobDb, 'feeds/alice/items/c1')));
});

test('owner can create a canonical user without legacy affinity', async () => {
  await assertSucceeds(
    setDoc(doc(harness.aliceDb, 'users/alice'), {
      display_name: 'Alice',
      username: 'alice',
      profile_visibility: 'public',
      searchable: true,
      theme_mode: 'dark',
      default_collection_view: 'map',
      reduced_motion: false,
      notifications_enabled: true,
      points: 0,
    }),
  );
});

test('user creation rejects legacy affinity', async () => {
  await assertFails(
    setDoc(doc(harness.bobDb, 'users/bob'), {
      display_name: 'Bob',
      points: 0,
      affinity: {},
    }),
  );
});

test('user creation rejects nonzero points', async () => {
  await assertFails(
    setDoc(doc(harness.charlieDb, 'users/charlie'), {
      display_name: 'Charlie',
      points: 1,
    }),
  );
});

test('user creation rejects another user', async () => {
  await assertFails(
    setDoc(doc(harness.aliceDb, 'users/bob'), {
      display_name: 'Bob',
      points: 0,
    }),
  );
});

test('user updates cannot set trusted fields', async () => {
  await assertSucceeds(
    setDoc(doc(harness.aliceDb, 'users/alice'), {
      display_name: 'Alice',
      points: 0,
    }),
  );
  await assertFails(
    updateDoc(doc(harness.aliceDb, 'users/alice'), {points: 999}),
  );
  await assertSucceeds(
    updateDoc(doc(harness.aliceDb, 'users/alice'), {theme_mode: 'dark'}),
  );
});

test('client cannot write trusted collections', async () => {
  await assertFails(
    setDoc(doc(harness.aliceDb, 'check_ins/c1'), {user_id: 'alice'}),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'friendships/alice_bob'), {
      member_uids: ['alice', 'bob'],
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'check_in_accounting/c1'), {
      user_id: 'alice',
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'place_aggregates/place-1'), {count: 1}),
  );
});

test('public profiles enforce public, friend and private visibility', async () => {
  await harness.seed('public_profiles/alice', {
    profile_visibility: 'private',
    searchable: false,
  });
  await harness.seed('public_profiles/bob', {
    profile_visibility: 'friends',
    searchable: false,
  });
  await harness.seed('public_profiles/charlie', {
    profile_visibility: 'public',
    searchable: true,
  });
  await harness.seed('friend_access/alice/members/bob', {
    friendship_id: 'alice_bob',
  });

  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'public_profiles/alice')),
  );
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'public_profiles/bob')),
  );
  await assertFails(getDoc(doc(harness.charlieDb, 'public_profiles/bob')));
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'public_profiles/charlie')),
  );
  await assertFails(getDoc(doc(harness.bobDb, 'public_profiles/alice')));
  await assertSucceeds(
    getDocs(
      query(
        collection(harness.aliceDb, 'public_profiles'),
        where('searchable', '==', true),
        where('profile_visibility', '==', 'public'),
      ),
    ),
  );
  await assertFails(getDocs(collection(harness.aliceDb, 'public_profiles')));
  await assertFails(
    setDoc(doc(harness.aliceDb, 'public_profiles/alice'), {
      profile_visibility: 'public',
      searchable: true,
    }),
  );
});

test('friendship documents are member-readable and projections stay private', async () => {
  await harness.seed('friendships/alice_bob', {
    member_uids: ['alice', 'bob'],
    state: 'accepted',
  });
  await harness.seed('friend_access/alice/members/bob', {
    friendship_id: 'alice_bob',
  });
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'friendships/alice_bob')),
  );
  await assertFails(
    getDoc(doc(harness.charlieDb, 'friendships/alice_bob')),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(harness.aliceDb, 'friendships'),
        where('member_uids', 'array-contains', 'alice'),
      ),
    ),
  );
  await assertFails(
    getDoc(doc(harness.aliceDb, 'friend_access/alice/members/bob')),
  );
});

test('place states are owner-only and accept only bounded client fields', async () => {
  const state = doc(
    harness.aliceDb,
    'users/alice/place_states/place-1',
  );
  await assertSucceeds(
    setDoc(state, {
      saved: true,
      saved_at: serverTimestamp(),
      favorite: false,
      liked: true,
      note: 'Pistacchio',
      updated_at: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(state));
  await assertFails(
    getDoc(
      doc(harness.bobDb, 'users/alice/place_states/place-1'),
    ),
  );
  await assertFails(updateDoc(state, {note: 'x'.repeat(501)}));
  await assertFails(updateDoc(state, {saved: 'yes'}));
  await assertFails(updateDoc(state, {points: 10}));
  await assertFails(
    getDoc(
      doc(harness.aliceDb, 'users/alice/place_visit_stats/place-1'),
    ),
  );
});

test('check-ins allow author queries and friend document reads only', async () => {
  await harness.seed('check_ins/c1', {user_id: 'alice'});
  await harness.seed('check_ins/c2', {user_id: 'charlie'});
  await harness.seed('friend_access/bob/members/alice', {
    friendship_id: 'alice_bob',
  });

  await assertSucceeds(getDoc(doc(harness.aliceDb, 'check_ins/c1')));
  await assertSucceeds(getDoc(doc(harness.bobDb, 'check_ins/c1')));
  await assertFails(getDoc(doc(harness.charlieDb, 'check_ins/c1')));
  await assertSucceeds(
    getDocs(
      query(
        collection(harness.aliceDb, 'check_ins'),
        where('user_id', '==', 'alice'),
      ),
    ),
  );
  await assertFails(getDocs(collection(harness.aliceDb, 'check_ins')));
  await assertFails(
    getDocs(
      query(
        collection(harness.bobDb, 'check_ins'),
        where('user_id', '==', 'alice'),
      ),
    ),
  );
});

test('catalog collections allow only exact validated creates', async () => {
  await assertSucceeds(
    setDoc(doc(harness.aliceDb, 'places/place-1'), {
      name: 'Gelateria Uno',
      address: 'Via Roma 1',
      location: new GeoPoint(41.9, 12.5),
      geohash: 'sr2yk',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'places/place-legacy'), {
      name: 'Gelateria Legacy',
      address: 'Via Roma 2',
      location: new GeoPoint(41.9, 12.5),
      geohash: 'sr2yk',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
      liked_by_uids: ['alice'],
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'places/place-foreign'), {
      name: 'Gelateria Foreign',
      address: 'Via Roma 3',
      location: new GeoPoint(41.9, 12.5),
      geohash: 'sr2yk',
      added_by_uid: 'bob',
      created_at: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(harness.aliceDb, 'places/place-1'), {name: 'Changed'}),
  );

  await assertSucceeds(
    setDoc(doc(harness.aliceDb, 'flavors/pistacchio'), {
      name: 'Pistacchio',
      name_lower: 'pistacchio',
      color_hex: '#87A96B',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(harness.aliceDb, 'flavors/crema'), {
      name: 'Crema',
      name_lower: 'crema',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'flavors/legacy'), {
      name: 'Legacy',
      name_lower: 'legacy',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
      liked_by_uids: [],
    }),
  );
  await assertFails(
    setDoc(doc(harness.aliceDb, 'flavors/bad-color'), {
      name: 'Bad',
      name_lower: 'bad',
      color_hex: 'green',
      added_by_uid: 'alice',
      created_at: serverTimestamp(),
    }),
  );
});

test('authenticated users read public catalogs but cannot mutate trusted data', async () => {
  await harness.seed('places/place-1', {name: 'Gelateria'});
  await harness.seed('flavors/flavor-1', {name: 'Crema'});
  await harness.seed('gelato_types/cup', {name: 'Coppetta'});
  await harness.seed('place_aggregates/place-1', {count: 2});
  await assertSucceeds(getDoc(doc(harness.aliceDb, 'places/place-1')));
  await assertSucceeds(getDoc(doc(harness.aliceDb, 'flavors/flavor-1')));
  await assertSucceeds(getDoc(doc(harness.aliceDb, 'gelato_types/cup')));
  await assertSucceeds(
    getDoc(doc(harness.aliceDb, 'place_aggregates/place-1')),
  );
  await assertFails(
    updateDoc(doc(harness.aliceDb, 'gelato_types/cup'), {name: 'Cono'}),
  );
  await assertFails(getDoc(doc(harness.aliceDb, 'unknown/secret')));
});

test('accepted friends can send and answer a Gelatino invite', async () => {
  await harness.seed('friend_access/alice/members/bob', {
    friendship_id: 'alice_bob',
  });
  const ping = doc(harness.aliceDb, 'pings/p1');
  await assertSucceeds(
    setDoc(ping, {
      member_uids: ['alice', 'bob'],
      sender_id: 'alice',
      receiver_id: 'bob',
      status: 'pending',
      created_at: serverTimestamp(),
      responded_at: null,
    }),
  );
  await assertFails(updateDoc(ping, {status: 'accepted'}));
  await assertSucceeds(
    updateDoc(doc(harness.bobDb, 'pings/p1'), {
      status: 'accepted',
      responded_at: serverTimestamp(),
    }),
  );
  await assertSucceeds(getDoc(doc(harness.aliceDb, 'pings/p1')));
  await assertFails(getDoc(doc(harness.charlieDb, 'pings/p1')));
});

test('unrelated users cannot create Gelatino invites', async () => {
  await assertFails(
    setDoc(doc(harness.aliceDb, 'pings/p2'), {
      member_uids: ['alice', 'charlie'],
      sender_id: 'alice',
      receiver_id: 'charlie',
      status: 'pending',
      created_at: serverTimestamp(),
      responded_at: null,
    }),
  );
});

test('ping lists require receiver or member query scope', async () => {
  await Promise.all([
    harness.seed('pings/recent-pending', {
      member_uids: ['alice', 'bob'],
      sender_id: 'alice',
      receiver_id: 'bob',
      status: 'pending',
      created_at: Timestamp.fromMillis(300),
      responded_at: null,
    }),
    harness.seed('pings/old-pending', {
      member_uids: ['bob', 'charlie'],
      sender_id: 'charlie',
      receiver_id: 'bob',
      status: 'pending',
      created_at: Timestamp.fromMillis(100),
      responded_at: null,
    }),
    harness.seed('pings/alice-history', {
      member_uids: ['alice', 'charlie'],
      sender_id: 'charlie',
      receiver_id: 'alice',
      status: 'accepted',
      created_at: Timestamp.fromMillis(200),
      responded_at: Timestamp.fromMillis(250),
    }),
  ]);

  await assertSucceeds(getDocs(query(
    collection(harness.bobDb, 'pings'),
    where('receiver_id', '==', 'bob'),
    where('status', '==', 'pending'),
    orderBy('created_at', 'desc'),
  )));
  await assertSucceeds(getDocs(query(
    collection(harness.aliceDb, 'pings'),
    where('member_uids', 'array-contains', 'alice'),
    orderBy('created_at', 'desc'),
  )));
  await assertFails(getDocs(query(
    collection(harness.aliceDb, 'pings'),
    where('receiver_id', '==', 'bob'),
    where('status', '==', 'pending'),
    orderBy('created_at', 'desc'),
  )));
  await assertFails(getDocs(collection(harness.aliceDb, 'pings')));
});

test('staging photos are owner-only JPEGs with exact paths and size limits', async () => {
  const aliceStorage = harness.storageUsers.alice.storage;
  const bobStorage = harness.storageUsers.bob.storage;
  const path = `staging/alice/${CHECK_IN_ID}.jpg`;

  await uploadBytes(ref(aliceStorage, path), JPEG, {contentType: 'image/jpeg'});
  await getBytes(ref(aliceStorage, path));
  await assert.rejects(getBytes(ref(bobStorage, path)));
  await assert.rejects(
    uploadBytes(ref(bobStorage, `staging/alice/${CHECK_IN_ID}B.jpg`), JPEG, {
      contentType: 'image/jpeg',
    }),
  );
  await assert.rejects(
    uploadBytes(ref(aliceStorage, `staging/alice/${CHECK_IN_ID}.png`), JPEG, {
      contentType: 'image/jpeg',
    }),
  );
  await assert.rejects(
    uploadBytes(ref(aliceStorage, `staging/alice/${CHECK_IN_ID}C.jpg`), JPEG, {
      contentType: 'image/png',
    }),
  );
  await assert.rejects(
    uploadBytes(
      ref(aliceStorage, `staging/alice/${CHECK_IN_ID}D.jpg`),
      new Uint8Array(5 * 1024 * 1024 + 1),
      {contentType: 'image/jpeg'},
    ),
  );
  await deleteObject(ref(aliceStorage, path));
});

test('permanent check-in photos are server-written and owner/friend-readable', async () => {
  const path = `check_ins/alice/${CHECK_IN_ID}/1.jpg`;
  await harness.seed('check_ins/ABCDEFGHIJKLMNOPQRST', {user_id: 'alice'});
  await harness.seed('friend_access/bob/members/alice', {
    friendship_id: 'alice_bob',
  });
  await harness.seedStorage(path, JPEG);

  await getBytes(ref(harness.storageUsers.alice.storage, path));
  await getBytes(ref(harness.storageUsers.bob.storage, path));
  await assert.rejects(
    getBytes(ref(harness.storageUsers.charlie.storage, path)),
  );
  await assert.rejects(
    uploadBytes(ref(harness.storageUsers.alice.storage, path), JPEG, {
      contentType: 'image/jpeg',
    }),
  );
});

test('permanent photo path must agree with the canonical check-in owner', async () => {
  const path = `check_ins/bob/${CHECK_IN_ID}/1.jpg`;
  await harness.seed('check_ins/ABCDEFGHIJKLMNOPQRST', {user_id: 'alice'});
  await harness.seedStorage(path, JPEG);
  await assert.rejects(getBytes(ref(harness.storageUsers.bob.storage, path)));
});

test('avatars are public to authenticated users but owner-written JPEGs only', async () => {
  const path = 'avatars/alice/1.jpg';
  await uploadBytes(ref(harness.storageUsers.alice.storage, path), JPEG, {
    contentType: 'image/jpeg',
  });
  await getBytes(ref(harness.storageUsers.bob.storage, path));
  await assert.rejects(
    uploadBytes(
      ref(harness.storageUsers.bob.storage, 'avatars/alice/2.jpg'),
      JPEG,
      {contentType: 'image/jpeg'},
    ),
  );
  await assert.rejects(
    uploadBytes(
      ref(harness.storageUsers.alice.storage, 'avatars/alice/3.jpg'),
      JPEG,
      {contentType: 'image/png'},
    ),
  );
  await assert.rejects(
    uploadBytes(
      ref(harness.storageUsers.alice.storage, 'avatars/alice/4.jpg'),
      new Uint8Array(2 * 1024 * 1024 + 1),
      {contentType: 'image/jpeg'},
    ),
  );
});
