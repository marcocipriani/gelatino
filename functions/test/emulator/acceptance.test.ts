import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails} from '@firebase/rules-unit-testing';
import {
  Firestore,
  Timestamp,
  collection,
  collectionGroup,
  endAt,
  getDocs,
  orderBy,
  query,
  startAt,
  where,
} from 'firebase/firestore';
import {pairId} from '../../src/domain/ids';
import {RulesHarness, createRulesHarness} from './helpers';

type IndexField = {
  fieldPath: string;
  order?: 'ASCENDING' | 'DESCENDING';
  arrayConfig?: 'CONTAINS';
};

type IndexDefinition = {
  collectionGroup: string;
  queryScope: 'COLLECTION' | 'COLLECTION_GROUP';
  fields: IndexField[];
};

type FieldOverride = {
  collectionGroup: string;
  fieldPath: string;
  indexes: Array<{
    order: 'ASCENDING' | 'DESCENDING';
    queryScope: 'COLLECTION' | 'COLLECTION_GROUP';
  }>;
};

const EXPECTED_INDEXES: IndexDefinition[] = [
  {
    collectionGroup: 'friendships',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'member_uids', arrayConfig: 'CONTAINS'},
      {fieldPath: 'state', order: 'ASCENDING'},
      {fieldPath: 'updated_at', order: 'DESCENDING'},
    ],
  },
  {
    collectionGroup: 'pings',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'receiver_id', order: 'ASCENDING'},
      {fieldPath: 'status', order: 'ASCENDING'},
      {fieldPath: 'created_at', order: 'DESCENDING'},
    ],
  },
  {
    collectionGroup: 'pings',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'member_uids', arrayConfig: 'CONTAINS'},
      {fieldPath: 'created_at', order: 'DESCENDING'},
    ],
  },
  {
    collectionGroup: 'place_states',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'favorite', order: 'ASCENDING'},
      {fieldPath: 'favorite_at', order: 'DESCENDING'},
    ],
  },
  {
    collectionGroup: 'place_states',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'saved', order: 'ASCENDING'},
      {fieldPath: 'saved_at', order: 'DESCENDING'},
    ],
  },
  {
    collectionGroup: 'public_profiles',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'searchable', order: 'ASCENDING'},
      {fieldPath: 'profile_visibility', order: 'ASCENDING'},
      {fieldPath: 'display_name_lower', order: 'ASCENDING'},
    ],
  },
  {
    collectionGroup: 'public_profiles',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'searchable', order: 'ASCENDING'},
      {fieldPath: 'profile_visibility', order: 'ASCENDING'},
      {fieldPath: 'username_lower', order: 'ASCENDING'},
    ],
  },
  {
    collectionGroup: 'items',
    queryScope: 'COLLECTION',
    fields: [
      {fieldPath: 'author_uid', order: 'ASCENDING'},
      {fieldPath: 'created_at', order: 'DESCENDING'},
    ],
  },
];

const EXPECTED_FIELD_OVERRIDES: FieldOverride[] = [
  {
    collectionGroup: 'items',
    fieldPath: 'check_in_id',
    indexes: [
      {order: 'ASCENDING', queryScope: 'COLLECTION_GROUP'},
    ],
  },
];

const timestamp = (milliseconds: number) =>
  Timestamp.fromMillis(milliseconds);

let harness: RulesHarness;

function friendship(
  requesterUid: string,
  recipientUid: string,
  state: 'pending' | 'accepted',
  updatedAt: Timestamp,
) {
  return {
    member_uids: [requesterUid, recipientUid].sort(),
    requester_uid: requesterUid,
    recipient_uid: recipientUid,
    state,
    requested_at: updatedAt,
    responded_at: state === 'accepted' ? updatedAt : null,
    accepted_at: state === 'accepted' ? updatedAt : null,
    removed_at: null,
    affinity_score: 0,
    updated_at: updatedAt,
  };
}

function publicProfile(
  uid: string,
  displayName: string,
  username: string,
  options: {
    visibility?: 'public' | 'friends' | 'private';
    searchable?: boolean;
  } = {},
) {
  return {
    uid,
    display_name: displayName,
    display_name_lower: displayName.toLowerCase(),
    username,
    username_lower: username.toLowerCase(),
    avatar_path: null,
    bio: '',
    city: '',
    favorite_place_id: null,
    favorite_flavor_id: null,
    favorite_flavor_ids: [],
    profile_visibility: options.visibility ?? 'public',
    searchable: options.searchable ?? true,
    points: 0,
    updated_at: timestamp(1),
  };
}

function ping(
  senderId: string,
  receiverId: string,
  status: 'pending' | 'accepted',
  createdAt: Timestamp,
) {
  return {
    member_uids: [senderId, receiverId].sort(),
    sender_id: senderId,
    receiver_id: receiverId,
    status,
    created_at: createdAt,
    responded_at: status === 'accepted' ? createdAt : null,
  };
}

function feedItem(
  authorUid: string,
  checkInId: string,
  createdAt: Timestamp,
) {
  return {
    author_uid: authorUid,
    check_in_id: checkInId,
    user_snapshot: {
      display_name: authorUid === 'alice' ? 'Alice' : 'Bob',
      username: authorUid,
      avatar_path: null,
    },
    place_id: 'gelateria-uno',
    place_snapshot: {name: 'Gelateria Uno', address: 'Via Roma 1'},
    gelato_type: {id: 'cup', name: 'Coppetta'},
    flavors: [{id: 'pistacchio', name: 'Pistacchio'}],
    rating: 5,
    review_text: 'Ottimo',
    tagged_user_ids: [],
    created_at: createdAt,
    photo_storage_path: `check_ins/${authorUid}/${checkInId}/1.jpg`,
  };
}

before(async () => {
  harness = await createRulesHarness();
});

beforeEach(async () => {
  await harness.clearFirestore();
});

after(async () => {
  await harness.cleanup();
});

test('declares the exact backend indexes with production query scopes', async () => {
  const raw = await readFile(
    resolve(__dirname, '../../../../firestore.indexes.json'),
    'utf8',
  );
  const config = JSON.parse(raw) as {
    indexes?: IndexDefinition[];
    fieldOverrides?: FieldOverride[];
  };
  assert.deepEqual(config.indexes, EXPECTED_INDEXES);
  assert.deepEqual(config.fieldOverrides, EXPECTED_FIELD_OVERRIDES);
});

test('lists accepted friendships for the authenticated member in update order', async () => {
  const aliceBob = pairId('alice', 'bob');
  const aliceCharlie = pairId('alice', 'charlie');
  await Promise.all([
    harness.seed(
      `friendships/${aliceBob}`,
      friendship('alice', 'bob', 'accepted', timestamp(300)),
    ),
    harness.seed(
      `friendships/${aliceCharlie}`,
      friendship('alice', 'charlie', 'accepted', timestamp(200)),
    ),
    harness.seed(
      `friendships/${pairId('alice', 'dora')}`,
      friendship('alice', 'dora', 'pending', timestamp(400)),
    ),
    harness.seed(
      `friendships/${pairId('bob', 'charlie')}`,
      friendship('bob', 'charlie', 'accepted', timestamp(500)),
    ),
  ]);

  const result = await getDocs(query(
    collection(harness.aliceDb, 'friendships'),
    where('member_uids', 'array-contains', 'alice'),
    where('state', '==', 'accepted'),
    orderBy('updated_at', 'desc'),
  ));

  assert.deepEqual(result.docs.map((document) => document.id), [
    aliceBob,
    aliceCharlie,
  ]);
  assert.ok(result.docs.every((document) =>
    document.get('state') === 'accepted' &&
    (document.get('member_uids') as unknown[]).includes('alice'),
  ));
});

test('orders only the authenticated owner feed', async () => {
  await Promise.all([
    harness.seed(
      'feeds/alice/items/check-in-new',
      feedItem('bob', 'check-in-new', timestamp(300)),
    ),
    harness.seed(
      'feeds/alice/items/check-in-old',
      feedItem('alice', 'check-in-old', timestamp(100)),
    ),
    harness.seed(
      'feeds/bob/items/check-in-foreign',
      feedItem('alice', 'check-in-foreign', timestamp(500)),
    ),
  ]);

  const result = await getDocs(query(
    collection(harness.aliceDb, 'feeds/alice/items'),
    orderBy('created_at', 'desc'),
  ));
  assert.deepEqual(result.docs.map((document) => document.id), [
    'check-in-new',
    'check-in-old',
  ]);
  await assertFails(getDocs(query(
    collection(harness.bobDb, 'feeds/alice/items'),
    orderBy('created_at', 'desc'),
  )));
});

test('searches public profiles by username and display-name prefixes', async () => {
  await Promise.all([
    harness.seed(
      'public_profiles/alice',
      publicProfile('alice', 'Alice Gelato', 'alba'),
    ),
    harness.seed(
      'public_profiles/bob',
      publicProfile('bob', 'Beatrice', 'alberto'),
    ),
    harness.seed(
      'public_profiles/charlie',
      publicProfile('charlie', 'Alessia', 'zed'),
    ),
    harness.seed(
      'public_profiles/dora',
      publicProfile('dora', 'Alina', 'alina', {searchable: false}),
    ),
    harness.seed(
      'public_profiles/eve',
      publicProfile('eve', 'Allegra', 'alicia', {visibility: 'private'}),
    ),
  ]);

  const prefix = 'al';
  const usernameResult = await getDocs(query(
    collection(harness.aliceDb, 'public_profiles'),
    where('searchable', '==', true),
    where('profile_visibility', '==', 'public'),
    orderBy('username_lower'),
    startAt(prefix),
    endAt(`${prefix}\uf8ff`),
  ));
  assert.deepEqual(usernameResult.docs.map((document) => document.id), [
    'alice',
    'bob',
  ]);

  const displayNameResult = await getDocs(query(
    collection(harness.aliceDb, 'public_profiles'),
    where('searchable', '==', true),
    where('profile_visibility', '==', 'public'),
    orderBy('display_name_lower'),
    startAt(prefix),
    endAt(`${prefix}\uf8ff`),
  ));
  assert.deepEqual(displayNameResult.docs.map((document) => document.id), [
    'charlie',
    'alice',
  ]);
  assert.ok([...usernameResult.docs, ...displayNameResult.docs].every(
    (document) =>
      document.get('searchable') === true &&
      document.get('profile_visibility') === 'public',
  ));
});

test('orders saved and favorite place states within the owner path', async () => {
  await Promise.all([
    harness.seed('users/alice/place_states/gelateria-a', {
      saved: true,
      saved_at: timestamp(100),
      favorite: true,
      favorite_at: timestamp(300),
    }),
    harness.seed('users/alice/place_states/gelateria-b', {
      saved: true,
      saved_at: timestamp(400),
      favorite: false,
      favorite_at: null,
    }),
    harness.seed('users/alice/place_states/gelateria-c', {
      saved: false,
      saved_at: null,
      favorite: true,
      favorite_at: timestamp(200),
    }),
    harness.seed('users/bob/place_states/gelateria-foreign', {
      saved: true,
      saved_at: timestamp(500),
      favorite: true,
      favorite_at: timestamp(500),
    }),
  ]);

  const saved = await getDocs(query(
    collection(harness.aliceDb, 'users/alice/place_states'),
    where('saved', '==', true),
    orderBy('saved_at', 'desc'),
  ));
  assert.deepEqual(saved.docs.map((document) => document.id), [
    'gelateria-b',
    'gelateria-a',
  ]);

  const favorites = await getDocs(query(
    collection(harness.aliceDb, 'users/alice/place_states'),
    where('favorite', '==', true),
    orderBy('favorite_at', 'desc'),
  ));
  assert.deepEqual(favorites.docs.map((document) => document.id), [
    'gelateria-a',
    'gelateria-c',
  ]);
  await assertFails(getDocs(query(
    collection(harness.bobDb, 'users/alice/place_states'),
    where('saved', '==', true),
    orderBy('saved_at', 'desc'),
  )));
});

test('finds every feed projection for a check-in through collection group', async () => {
  await Promise.all([
    harness.seed(
      'feeds/alice/items/check-in-target',
      feedItem('alice', 'check-in-target', timestamp(300)),
    ),
    harness.seed(
      'feeds/bob/items/check-in-target',
      feedItem('alice', 'check-in-target', timestamp(300)),
    ),
    harness.seed(
      'feeds/charlie/items/check-in-other',
      feedItem('charlie', 'check-in-other', timestamp(200)),
    ),
  ]);

  let paths: string[] = [];
  await harness.environment.withSecurityRulesDisabled(async (context) => {
    const result = await getDocs(query(
      collectionGroup(
        context.firestore() as unknown as Firestore,
        'items',
      ),
      where('check_in_id', '==', 'check-in-target'),
    ));
    paths = result.docs.map((document) => document.ref.path).sort();
  });
  assert.deepEqual(paths, [
    'feeds/alice/items/check-in-target',
    'feeds/bob/items/check-in-target',
  ]);
});

test('orders receiver inbox and member invitation history', async () => {
  await Promise.all([
    harness.seed(
      'pings/recent-pending',
      ping('alice', 'bob', 'pending', timestamp(400)),
    ),
    harness.seed(
      'pings/old-pending',
      ping('charlie', 'bob', 'pending', timestamp(100)),
    ),
    harness.seed(
      'pings/accepted',
      ping('alice', 'bob', 'accepted', timestamp(300)),
    ),
    harness.seed(
      'pings/other-receiver',
      ping('bob', 'alice', 'pending', timestamp(500)),
    ),
  ]);

  const inbox = await getDocs(query(
    collection(harness.bobDb, 'pings'),
    where('receiver_id', '==', 'bob'),
    where('status', '==', 'pending'),
    orderBy('created_at', 'desc'),
  ));
  assert.deepEqual(inbox.docs.map((document) => document.id), [
    'recent-pending',
    'old-pending',
  ]);
  assert.ok(inbox.docs.every((document) =>
    document.get('receiver_id') === 'bob' &&
    document.get('status') === 'pending',
  ));

  const history = await getDocs(query(
    collection(harness.aliceDb, 'pings'),
    where('member_uids', 'array-contains', 'alice'),
    orderBy('created_at', 'desc'),
  ));
  assert.deepEqual(history.docs.map((document) => document.id), [
    'other-receiver',
    'recent-pending',
    'accepted',
  ]);
  assert.ok(history.docs.every((document) =>
    (document.get('member_uids') as unknown[]).includes('alice'),
  ));
});
