import assert from 'node:assert/strict';
import {test} from 'node:test';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {pairId} from '../../src/domain/ids';
import {deleteAccountData} from '../../src/services/account';
import {PROJECT_ID, STORAGE_BUCKET} from './helpers';

const app = initializeApp(
  {projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET},
  'account-test',
);
const db = getFirestore(app);
const bucket = getStorage(app).bucket();

test('account deletion removes owned data and keeps other users', async () => {
  const friendshipId = pairId('yan', 'zoe');
  const checkInId = 'ZOEABCDEFGHIJKLMNOPQ';
  await Promise.all([
    db.doc('users/zoe').set({points: 3}),
    db.doc('users/zoe/place_states/p1').set({saved: true}),
    db.doc('users/zoe/fcm_tokens/t1').set({platform: 'web'}),
    db.doc('public_profiles/zoe').set({uid: 'zoe'}),
    db.doc('users/yan').set({points: 1}),
    db.doc('public_profiles/yan').set({uid: 'yan'}),
    db.doc(`friendships/${friendshipId}`).set({
      member_uids: ['yan', 'zoe'],
      state: 'accepted',
    }),
    db.doc('friend_access/zoe/members/yan').set({friendship_id: friendshipId}),
    db.doc('pings/ping1').set({member_uids: ['yan', 'zoe']}),
    db.doc('feeds/zoe/items/x').set({author_uid: 'yan'}),
    // No accounting doc: the owner deletion refuses it, the raw path runs.
    db.doc(`check_ins/${checkInId}`).set({user_id: 'zoe'}),
    bucket.file('avatars/zoe/a.jpg').save('x'),
    bucket.file('staging/zoe/s.jpg').save('x'),
    bucket.file('avatars/yan/b.jpg').save('x'),
  ]);
  const deleted: string[] = [];

  await deleteAccountData(db, bucket, {
    deleteUser: async (uid: string) => {
      deleted.push(uid);
    },
  }, 'zoe');

  for (const path of [
    'users/zoe',
    'users/zoe/place_states/p1',
    'users/zoe/fcm_tokens/t1',
    'public_profiles/zoe',
    `friendships/${friendshipId}`,
    'friend_access/zoe/members/yan',
    'pings/ping1',
    'feeds/zoe/items/x',
    `check_ins/${checkInId}`,
  ]) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }
  assert.equal((await db.doc('users/yan').get()).exists, true);
  assert.equal((await bucket.file('avatars/zoe/a.jpg').exists())[0], false);
  assert.equal((await bucket.file('staging/zoe/s.jpg').exists())[0], false);
  assert.equal((await bucket.file('avatars/yan/b.jpg').exists())[0], true);
  assert.deepEqual(deleted, ['zoe']);

  // Retrying after a partial failure must not throw.
  await deleteAccountData(db, bucket, {deleteUser: async () => {}}, 'zoe');
});
