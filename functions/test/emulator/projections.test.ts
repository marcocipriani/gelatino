import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {getStorage as getAdminStorage} from 'firebase-admin/storage';
import {
  Firestore,
  Timestamp,
  getFirestore as getAdminFirestore,
} from 'firebase-admin/firestore';
import {pairId} from '../../src/domain/ids';
import {
  onCheckInCreated,
  onCheckInDeleted,
  projectCheckInCreated,
  projectCheckInDeleted,
} from '../../src/triggers/check_in_projection';
import {projectFriendshipChanged} from '../../src/triggers/friendship_projection';
import {cleanupMedia} from '../../src/triggers/media_cleanup';
import {
  syncCurrentPublicProfile,
  syncPublicProfile,
} from '../../src/triggers/profile_sync';
import {
  RulesHarness,
  STORAGE_BUCKET,
  createRulesHarness,
} from './helpers';

const CHECK_IN_ID = 'ABCDEFGHIJKLMNOPQRST';
const OTHER_CHECK_IN_ID = 'BCDEFGHIJKLMNOPQRSTU';
const REFERENCED_CHECK_IN_ID = 'CDEFGHIJKLMNOPQRSTUV';
const MISMATCHED_CHECK_IN_ID = 'DEFGHIJKLMNOPQRSTUVW';
const now = Timestamp.fromMillis(1_750_000_000_000);

let harness: RulesHarness;
let db: Firestore;

function privateUser(overrides: Record<string, unknown> = {}) {
  return {
    display_name: 'Alice',
    display_name_lower: 'alice',
    username: 'alice-gelato',
    username_lower: 'alice-gelato',
    avatar_path: null,
    bio: 'Bio pubblica',
    city: 'Roma',
    favorite_place_id: 'place-1',
    favorite_flavor_id: 'pistacchio',
    favorite_flavor_ids: ['pistacchio'],
    profile_visibility: 'friends',
    searchable: false,
    points: 10,
    email: 'alice@example.test',
    affinity: {bob: 100},
    notifications_enabled: true,
    theme_mode: 'dark',
    ...overrides,
  };
}

function checkIn(overrides: Record<string, unknown> = {}) {
  return {
    user_id: 'alice',
    user_snapshot: {
      display_name: 'Alice',
      username: 'alice-gelato',
      avatar_path: null,
    },
    place_id: 'place-1',
    place_snapshot: {name: 'Gelateria Uno', address: 'Via Roma 1'},
    gelato_type: {id: 'cono', name: 'Cono'},
    flavors: [{id: 'pistacchio', name: 'Pistacchio'}],
    rating: 5,
    review_text: 'Delizioso',
    tagged_user_ids: ['bob'],
    photo_storage_path: `check_ins/alice/${CHECK_IN_ID}/1.jpg`,
    created_at: now,
    updated_at: now,
    schema_version: 2,
    ...overrides,
  };
}

async function snapshot(path: string) {
  return db.doc(path).get();
}

async function storageExists(path: string): Promise<boolean> {
  const [exists] = await getAdminStorage(harness.adminApp)
    .bucket(STORAGE_BUCKET)
    .file(path)
    .exists();
  return exists;
}

before(async () => {
  harness = await createRulesHarness();
  db = getAdminFirestore(harness.adminApp);
});

beforeEach(async () => {
  await harness.clearFirestore();
  await getAdminStorage(harness.adminApp)
    .bucket(STORAGE_BUCKET)
    .deleteFiles({prefix: ''});
});

after(async () => {
  await harness.cleanup();
});

test('profile create/update/delete replaces stale keys with an exact allowlist', async () => {
  await db.doc('public_profiles/alice').set({stale_private_key: 'secret'});
  await syncPublicProfile(db, 'alice', privateUser(), now);

  const created = await snapshot('public_profiles/alice');
  assert.equal(created.exists, true);
  assert.deepEqual(Object.keys(created.data()!).sort(), [
    'avatar_path',
    'bio',
    'city',
    'display_name',
    'display_name_lower',
    'favorite_flavor_id',
    'favorite_flavor_ids',
    'favorite_place_id',
    'monthly_points',
    'points',
    'profile_visibility',
    'searchable',
    'uid',
    'updated_at',
    'username',
    'username_lower',
  ]);
  assert.equal(created.get('email'), undefined);
  assert.equal(created.get('affinity'), undefined);

  await syncPublicProfile(
    db,
    'alice',
    privateUser({bio: 'Nuova bio', favorite_flavor_ids: []}),
    Timestamp.fromMillis(now.toMillis() + 1),
  );
  const updated = await snapshot('public_profiles/alice');
  assert.equal(updated.get('bio'), 'Nuova bio');
  assert.deepEqual(updated.get('favorite_flavor_ids'), []);
  assert.equal(updated.get('stale_private_key'), undefined);

  await syncPublicProfile(db, 'alice', null, now);
  assert.equal((await snapshot('public_profiles/alice')).exists, false);
});

test('a stale user delete event cannot erase a recreated user projection', async () => {
  await Promise.all([
    db.doc('users/alice').set(privateUser()),
    db.doc('public_profiles/alice').set({uid: 'alice', marker: 'current'}),
  ]);

  await syncCurrentPublicProfile(db, 'alice', now);

  const projection = await snapshot('public_profiles/alice');
  assert.equal(projection.exists, true);
  assert.equal(projection.get('uid'), 'alice');
  assert.equal(projection.get('marker'), undefined);
});

test('a stale user update event projects the canonical current user', async () => {
  await db.doc('users/alice').set(privateUser({bio: 'Canonical bio'}));

  await syncCurrentPublicProfile(db, 'alice', now);

  const projection = await snapshot('public_profiles/alice');
  assert.equal(projection.get('bio'), 'Canonical bio');
});

test('check-in projection fans out only to accepted friends and is idempotent', async () => {
  await db.doc(`friendships/${pairId('alice', 'bob')}`).set({
    member_uids: ['alice', 'bob'],
    state: 'accepted',
  });
  await db.doc(`friendships/${pairId('alice', 'charlie')}`).set({
    member_uids: ['alice', 'charlie'],
    state: 'pending',
  });

  await projectCheckInCreated(db, CHECK_IN_ID, 'create-event-1', checkIn());
  await projectCheckInCreated(db, CHECK_IN_ID, 'create-event-1', checkIn());

  const aliceItem = await snapshot(`feeds/alice/items/${CHECK_IN_ID}`);
  const bobItem = await snapshot(`feeds/bob/items/${CHECK_IN_ID}`);
  const charlieItem = await snapshot(`feeds/charlie/items/${CHECK_IN_ID}`);
  assert.equal(aliceItem.exists, true);
  assert.equal(bobItem.exists, true);
  assert.equal(charlieItem.exists, false);
  assert.deepEqual(Object.keys(aliceItem.data()!).sort(), [
    'author_uid',
    'check_in_id',
    'created_at',
    'flavors',
    'gelato_type',
    'photo_storage_path',
    'place_id',
    'place_snapshot',
    'rating',
    'review_text',
    'tagged_user_ids',
    'user_snapshot',
  ]);
  assert.equal(aliceItem.get('affinity'), undefined);

  const feedItems = await db.collectionGroup('items')
    .where('check_in_id', '==', CHECK_IN_ID)
    .get();
  assert.equal(feedItems.size, 2);
  const aggregate = await snapshot('place_aggregates/place-1');
  assert.deepEqual(Object.keys(aggregate.data()!).sort(), [
    'check_in_count',
    'rating_average',
    'rating_sum',
    'updated_at',
  ]);
  assert.equal(aggregate.get('check_in_count'), 1);
  assert.equal(aggregate.get('rating_sum'), 5);
  assert.equal(aggregate.get('rating_average'), 5);
  assert.deepEqual(
    (await snapshot(`check_in_projection_states/${CHECK_IN_ID}`)).data(),
    {
      state: 'counted',
      author_uid: 'alice',
      place_id: 'place-1',
      rating: 5,
      updated_at: (await snapshot(
        `check_in_projection_states/${CHECK_IN_ID}`,
      )).get('updated_at'),
    },
  );
});

test('a tombstone blocks late create and cleans every exact stale feed', async () => {
  await Promise.all([
    db.doc(`check_in_tombstones/${CHECK_IN_ID}`).set({
      owner_uid: 'alice',
      deleted_at: now,
      schema_version: 1,
    }),
    db.doc(`feeds/alice/items/${CHECK_IN_ID}`).set({
      check_in_id: CHECK_IN_ID,
    }),
    db.doc(`feeds/bob/items/${CHECK_IN_ID}`).set({
      check_in_id: CHECK_IN_ID,
    }),
    db.doc(`unrelated/sentinel/items/${CHECK_IN_ID}`).set({
      check_in_id: CHECK_IN_ID,
    }),
  ]);

  await projectCheckInCreated(
    db,
    CHECK_IN_ID,
    'late-create-event',
    checkIn(),
  );

  assert.equal(
    (await snapshot(`feeds/alice/items/${CHECK_IN_ID}`)).exists,
    false,
  );
  assert.equal(
    (await snapshot(`feeds/bob/items/${CHECK_IN_ID}`)).exists,
    false,
  );
  assert.equal(
    (await snapshot(`unrelated/sentinel/items/${CHECK_IN_ID}`)).exists,
    true,
  );
  assert.equal((await snapshot('place_aggregates/place-1')).exists, false);
  assert.equal(
    (await snapshot(`check_in_projection_states/${CHECK_IN_ID}`)).get('state'),
    'deleted',
  );
});

test('check-in deletion removes every feed copy, clamps once and deletes only its prefix', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  await Promise.all([
    db.doc(`feeds/alice/items/${CHECK_IN_ID}`).set({check_in_id: CHECK_IN_ID}),
    db.doc(`feeds/bob/items/${CHECK_IN_ID}`).set({check_in_id: CHECK_IN_ID}),
    db.doc(`feeds/charlie/items/${CHECK_IN_ID}`).set({check_in_id: CHECK_IN_ID}),
    db.doc('place_aggregates/place-1').set({
      check_in_count: 1,
      rating_sum: 5,
      rating_average: 5,
      updated_at: now,
    }),
    db.doc(`check_in_projection_states/${CHECK_IN_ID}`).set({
      state: 'counted',
      author_uid: 'alice',
      place_id: 'place-1',
      rating: 5,
      updated_at: now,
    }),
    db.doc(`feeds/charlie/items/not-the-id`).set({
      check_in_id: CHECK_IN_ID,
    }),
    db.doc(`unrelated/sentinel/items/${CHECK_IN_ID}`).set({
      check_in_id: CHECK_IN_ID,
    }),
    bucket.file(`check_ins/alice/${CHECK_IN_ID}/1.jpg`).save('one'),
    bucket.file(`check_ins/alice/${CHECK_IN_ID}/2.jpg`).save('two'),
    bucket.file(`check_ins/alice/${OTHER_CHECK_IN_ID}/1.jpg`).save('other'),
  ]);

  await projectCheckInDeleted(
    db,
    bucket,
    CHECK_IN_ID,
    'delete-event-1',
    checkIn(),
  );
  await projectCheckInDeleted(
    db,
    bucket,
    CHECK_IN_ID,
    'delete-event-1',
    checkIn(),
  );

  for (const uid of ['alice', 'bob', 'charlie']) {
    assert.equal(
      (await snapshot(`feeds/${uid}/items/${CHECK_IN_ID}`)).exists,
      false,
    );
  }
  assert.equal(
    (await snapshot('feeds/charlie/items/not-the-id')).exists,
    true,
  );
  assert.equal(
    (await snapshot(`unrelated/sentinel/items/${CHECK_IN_ID}`)).exists,
    true,
  );
  const aggregate = await snapshot('place_aggregates/place-1');
  assert.deepEqual(aggregate.data(), {
    check_in_count: 0,
    rating_sum: 0,
    rating_average: 0,
    updated_at: aggregate.get('updated_at'),
  });
  assert.equal(
    await storageExists(`check_ins/alice/${CHECK_IN_ID}/1.jpg`),
    false,
  );
  assert.equal(
    await storageExists(`check_ins/alice/${CHECK_IN_ID}/2.jpg`),
    false,
  );
  assert.equal(
    await storageExists(`check_ins/alice/${OTHER_CHECK_IN_ID}/1.jpg`),
    true,
  );
  assert.equal(
    (await snapshot(`check_in_projection_states/${CHECK_IN_ID}`)).get('state'),
    'deleted',
  );
});

test('delete-before-create never decrements a pre-existing aggregate', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  await db.doc('place_aggregates/place-1').set({
    check_in_count: 4,
    rating_sum: 14,
    rating_average: 3.5,
    updated_at: now,
  });

  await projectCheckInDeleted(
    db,
    bucket,
    CHECK_IN_ID,
    'delete-before-create',
    checkIn(),
  );
  await db.doc(`check_in_tombstones/${CHECK_IN_ID}`).set({
    owner_uid: 'alice',
    deleted_at: now,
    schema_version: 1,
  });
  await projectCheckInCreated(
    db,
    CHECK_IN_ID,
    'late-create-after-delete',
    checkIn(),
  );

  const aggregate = await snapshot('place_aggregates/place-1');
  assert.equal(aggregate.get('check_in_count'), 4);
  assert.equal(aggregate.get('rating_sum'), 14);
  assert.equal(
    (await snapshot(`check_in_projection_states/${CHECK_IN_ID}`)).get('state'),
    'deleted',
  );
});

test('a removed feed candidate is never published during create', async () => {
  const friendshipId = pairId('alice', 'bob');
  await db.doc(`friendships/${friendshipId}`).set({
    member_uids: ['alice', 'bob'],
    state: 'accepted',
  });

  await projectCheckInCreated(
    db,
    CHECK_IN_ID,
    'remove-during-fanout',
    checkIn(),
    {
      afterCandidateQuery: async () => {
        assert.equal(
          (await snapshot(`feeds/bob/items/${CHECK_IN_ID}`)).exists,
          false,
        );
        await db.doc(`friendships/${friendshipId}`).update({state: 'removed'});
        assert.equal(
          (await snapshot(`feeds/bob/items/${CHECK_IN_ID}`)).exists,
          false,
        );
      },
    },
  );

  assert.equal(
    (await snapshot(`feeds/alice/items/${CHECK_IN_ID}`)).exists,
    true,
  );
  assert.equal(
    (await snapshot(`feeds/bob/items/${CHECK_IN_ID}`)).exists,
    false,
  );
});

test('friendship removal repairs edges and deletes only cross-authored feed items', async () => {
  const friendshipId = pairId('alice', 'bob');
  await Promise.all([
    db.doc('friend_access/alice/members/bob').set({friendship_id: friendshipId}),
    db.doc('friend_access/bob/members/alice').set({friendship_id: friendshipId}),
    db.doc('feeds/alice/items/a-from-b').set({author_uid: 'bob'}),
    db.doc('feeds/alice/items/a-from-a').set({author_uid: 'alice'}),
    db.doc('feeds/bob/items/b-from-a').set({author_uid: 'alice'}),
    db.doc('feeds/bob/items/b-from-b').set({author_uid: 'bob'}),
  ]);

  await projectFriendshipChanged(db, friendshipId, {
    member_uids: ['alice', 'bob'],
    state: 'removed',
  });

  assert.equal((await snapshot('friend_access/alice/members/bob')).exists, false);
  assert.equal((await snapshot('friend_access/bob/members/alice')).exists, false);
  assert.equal((await snapshot('feeds/alice/items/a-from-b')).exists, false);
  assert.equal((await snapshot('feeds/bob/items/b-from-a')).exists, false);
  assert.equal((await snapshot('feeds/alice/items/a-from-a')).exists, true);
  assert.equal((await snapshot('feeds/bob/items/b-from-b')).exists, true);

  await projectFriendshipChanged(db, friendshipId, {
    member_uids: ['alice', 'bob'],
    state: 'accepted',
  });
  assert.equal(
    (await snapshot('friend_access/alice/members/bob')).get('friendship_id'),
    friendshipId,
  );
  assert.equal(
    (await snapshot('friend_access/bob/members/alice')).get('friendship_id'),
    friendshipId,
  );
});

test('a stale friendship event projects the canonical current state', async () => {
  const friendshipId = pairId('alice', 'bob');
  await Promise.all([
    db.doc(`friendships/${friendshipId}`).set({
      member_uids: ['alice', 'bob'],
      state: 'accepted',
    }),
    db.doc('feeds/alice/items/from-b').set({author_uid: 'bob'}),
  ]);

  await projectFriendshipChanged(db, friendshipId, {
    member_uids: ['alice', 'bob'],
    state: 'removed',
  });

  assert.equal(
    (await snapshot('friend_access/alice/members/bob')).get('friendship_id'),
    friendshipId,
  );
  assert.equal((await snapshot('feeds/alice/items/from-b')).exists, true);
});

test('friendship cleanup rechecks canonical state before every delete batch', async () => {
  const friendshipId = pairId('alice', 'bob');
  const writer = db.bulkWriter();
  for (let index = 0; index < 505; index += 1) {
    writer.set(db.doc(`feeds/bob/items/from-alice-${index}`), {
      author_uid: 'alice',
    });
  }
  await writer.close();

  let switched = false;
  await projectFriendshipChanged(
    db,
    friendshipId,
    {member_uids: ['alice', 'bob'], state: 'removed'},
    {
      beforeFeedDeleteBatch: async () => {
        if (switched) return;
        switched = true;
        await db.doc(`friendships/${friendshipId}`).set({
          member_uids: ['alice', 'bob'],
          state: 'accepted',
        });
      },
    },
  );

  const remaining = await db.collection('feeds/bob/items')
    .where('author_uid', '==', 'alice')
    .get();
  assert.equal(remaining.size, 505);
  assert.equal(
    (await snapshot('friend_access/alice/members/bob')).get('friendship_id'),
    friendshipId,
  );
});

test('cleanup deletes old abandoned media and preserves referenced and fresh objects', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const referencedPath = `check_ins/alice/${REFERENCED_CHECK_IN_ID}/1.jpg`;
  const mismatchedPath = `check_ins/alice/${MISMATCHED_CHECK_IN_ID}/1.jpg`;
  const oldStagingPath = `staging/alice/${CHECK_IN_ID}.jpg`;
  const oldOrphanPath = `check_ins/alice/${OTHER_CHECK_IN_ID}/1.jpg`;
  await Promise.all([
    bucket.file(oldStagingPath).save('staging'),
    bucket.file(oldOrphanPath).save('orphan'),
    bucket.file(referencedPath).save('referenced'),
    bucket.file(mismatchedPath).save('mismatched'),
    db.doc(`check_ins/${REFERENCED_CHECK_IN_ID}`).set({
      user_id: 'alice',
      photo_storage_path: referencedPath,
    }),
    db.doc(`check_ins/${MISMATCHED_CHECK_IN_ID}`).set({
      user_id: 'bob',
      photo_storage_path: mismatchedPath,
    }),
  ]);

  const future = new Date(Date.now() + 25 * 60 * 60 * 1000);
  const result = await cleanupMedia(db, bucket, future);
  assert.equal(result.deletedStaging, 1);
  assert.equal(result.deletedPermanent, 2);
  assert.equal(await storageExists(oldStagingPath), false);
  assert.equal(await storageExists(oldOrphanPath), false);
  assert.equal(await storageExists(mismatchedPath), false);
  assert.equal(await storageExists(referencedPath), true);

  const freshStagingPath = `staging/alice/${OTHER_CHECK_IN_ID}.jpg`;
  const freshPermanentPath = `check_ins/alice/${CHECK_IN_ID}/fresh.jpg`;
  await Promise.all([
    bucket.file(freshStagingPath).save('fresh'),
    bucket.file(freshPermanentPath).save('fresh'),
  ]);
  await cleanupMedia(db, bucket, new Date());
  assert.equal(await storageExists(freshStagingPath), true);
  assert.equal(await storageExists(freshPermanentPath), true);
});

test('corrupt events fail closed without broad writes or deletion', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const sentinel = `check_ins/alice/${OTHER_CHECK_IN_ID}/1.jpg`;
  await bucket.file(sentinel).save('sentinel');

  await assert.rejects(
    projectCheckInCreated(
      db,
      CHECK_IN_ID,
      'corrupt-create-event',
      checkIn({rating: Number.MAX_SAFE_INTEGER}),
    ),
    /rating/,
  );
  await assert.rejects(
    projectCheckInDeleted(
      db,
      bucket,
      '../bad',
      'corrupt-delete-event',
      checkIn({user_id: '../alice'}),
    ),
    /checkInId/,
  );
  await assert.rejects(
    projectFriendshipChanged(db, pairId('alice', 'bob'), {
      member_uids: ['alice', '../bob'],
      state: 'removed',
    }),
    /member_uids/,
  );

  assert.equal((await db.collectionGroup('items').get()).empty, true);
  assert.equal((await snapshot('place_aggregates/place-1')).exists, false);
  assert.equal(await storageExists(sentinel), true);
});

test('corrupt aggregate state propagates before feed or Storage deletion', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const feedPath = `feeds/alice/items/${CHECK_IN_ID}`;
  const mediaPath = `check_ins/alice/${CHECK_IN_ID}/1.jpg`;
  await Promise.all([
    db.doc(feedPath).set({check_in_id: CHECK_IN_ID}),
    db.doc(`check_in_projection_states/${CHECK_IN_ID}`).set({
      state: 'counted',
      author_uid: 'alice',
      place_id: 'place-1',
      rating: 5,
      updated_at: now,
    }),
    db.doc('place_aggregates/place-1').set({
      check_in_count: 'corrupt',
      rating_sum: 5,
      rating_average: 5,
      updated_at: now,
    }),
    bucket.file(mediaPath).save('media'),
  ]);

  await assert.rejects(
    projectCheckInDeleted(
      db,
      bucket,
      CHECK_IN_ID,
      'corrupt-aggregate-delete',
      checkIn(),
    ),
    /check_in_count/,
  );
  await assert.rejects(
    onCheckInDeleted.run({
      data: {data: () => checkIn()},
      id: 'corrupt-aggregate-wrapper',
      params: {checkInId: CHECK_IN_ID},
    } as never),
    /check_in_count/,
  );
  assert.equal((await snapshot(feedPath)).exists, true);
  assert.equal(await storageExists(mediaPath), true);
});

test('a delete receipt requires a deleted lifecycle before cleanup', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const eventId = 'delete-receipt-counted';
  const feedPath = `feeds/alice/items/${CHECK_IN_ID}`;
  const mediaPath = `check_ins/alice/${CHECK_IN_ID}/1.jpg`;
  const aggregateData = {
    check_in_count: 2,
    rating_sum: 8,
    rating_average: 4,
    updated_at: now,
  };
  await Promise.all([
    db.doc(feedPath).set({check_in_id: CHECK_IN_ID}),
    db.doc(`check_in_projection_states/${CHECK_IN_ID}`).set({
      state: 'counted',
      author_uid: 'alice',
      place_id: 'place-1',
      rating: 5,
      updated_at: now,
    }),
    db.doc('place_aggregates/place-1').set(aggregateData),
    db.doc(`event_receipts/checkin-deleted-${eventId}`).set({
      check_in_id: CHECK_IN_ID,
      created_at: now,
    }),
    bucket.file(mediaPath).save('media'),
  ]);

  await assert.rejects(
    onCheckInDeleted.run({
      data: {data: () => checkIn()},
      id: eventId,
      params: {checkInId: CHECK_IN_ID},
    } as never),
    /deleted lifecycle/,
  );
  const aggregate = await snapshot('place_aggregates/place-1');
  assert.deepEqual(aggregate.data(), aggregateData);
  assert.equal((await snapshot(feedPath)).exists, true);
  assert.equal(await storageExists(mediaPath), true);
});

test('delete projection rejects malformed internal receipts before cleanup', async () => {
  const bucket = getAdminStorage(harness.adminApp).bucket(STORAGE_BUCKET);
  const feedPath = `feeds/alice/items/${CHECK_IN_ID}`;
  const mediaPath = `check_ins/alice/${CHECK_IN_ID}/1.jpg`;
  await Promise.all([
    db.doc(feedPath).set({check_in_id: CHECK_IN_ID}),
    db.doc(`check_in_projection_states/${CHECK_IN_ID}`).set({
      state: 'deleted',
      author_uid: 'alice',
      place_id: 'place-1',
      rating: 5,
      updated_at: now,
    }),
    bucket.file(mediaPath).save('media'),
  ]);

  const corruptReceipts = [
    {
      eventId: 'receipt-wrong-check-in',
      data: {check_in_id: OTHER_CHECK_IN_ID, created_at: now},
    },
    {
      eventId: 'receipt-invalid-timestamp',
      data: {check_in_id: CHECK_IN_ID, created_at: 'not-a-timestamp'},
    },
    {
      eventId: 'receipt-unexpected-field',
      data: {check_in_id: CHECK_IN_ID, created_at: now, unexpected: true},
    },
  ];
  for (const receipt of corruptReceipts) {
    await db.doc(`event_receipts/checkin-deleted-${receipt.eventId}`)
      .set(receipt.data);
    await assert.rejects(
      projectCheckInDeleted(
        db,
        bucket,
        CHECK_IN_ID,
        receipt.eventId,
        checkIn(),
      ),
      /event_receipts/,
    );
    assert.equal((await snapshot(feedPath)).exists, true);
    assert.equal(await storageExists(mediaPath), true);
  }
});

test('a corrupt accepted friendship cannot broaden feed recipients', async () => {
  await db.doc('friendships/not-the-canonical-pair').set({
    member_uids: ['alice', 'charlie'],
    state: 'accepted',
  });

  await assert.rejects(
    projectCheckInCreated(
      db,
      CHECK_IN_ID,
      'corrupt-friendship-event',
      checkIn(),
    ),
    /friendship.*invalid/i,
  );
  await assert.rejects(
    onCheckInCreated.run({
      data: {data: () => checkIn()},
      id: 'corrupt-friendship-wrapper',
      params: {checkInId: CHECK_IN_ID},
    } as never),
    /friendship.*invalid/i,
  );
  assert.equal((await db.collectionGroup('items').get()).empty, true);
  assert.equal((await snapshot('place_aggregates/place-1')).exists, false);
});
