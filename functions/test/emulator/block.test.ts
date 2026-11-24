import assert from 'node:assert/strict';
import {test} from 'node:test';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {pairId} from '../../src/domain/ids';
import {
  blockUser,
  sendRequest,
  unblockUser,
} from '../../src/services/friendships';
import {PROJECT_ID} from './helpers';

const db = getFirestore(initializeApp({projectId: PROJECT_ID}, 'block-test'));

test('blocking ends the friendship and stops requests both ways', async () => {
  const id = pairId('kim', 'lea');
  await Promise.all([
    db.doc('public_profiles/kim').set({uid: 'kim'}),
    db.doc('public_profiles/lea').set({uid: 'lea'}),
    db.doc(`friendships/${id}`).set({
      member_uids: ['kim', 'lea'],
      requester_uid: 'kim',
      recipient_uid: 'lea',
      state: 'accepted',
      affinity_score: 2,
    }),
    db.doc('friend_access/kim/members/lea').set({friendship_id: id}),
    db.doc('friend_access/lea/members/kim').set({friendship_id: id}),
  ]);

  assert.equal((await blockUser(db, 'lea', 'kim')).state, 'blocked');
  const blocked = (await db.doc(`friendships/${id}`).get()).data()!;
  assert.equal(blocked.state, 'blocked');
  assert.equal(blocked.requester_uid, 'lea');
  assert.equal((await db.doc('friend_access/kim/members/lea').get()).exists, false);
  assert.equal((await db.doc('friend_access/lea/members/kim').get()).exists, false);

  await assert.rejects(sendRequest(db, 'kim', 'lea'), /blocked/);
  await assert.rejects(sendRequest(db, 'lea', 'kim'), /blocked/);
  // Only the blocker can unblock; blocking again is a no-op.
  await assert.rejects(unblockUser(db, 'kim', 'lea'));
  assert.equal((await blockUser(db, 'kim', 'lea')).requesterUid, 'lea');

  assert.equal((await unblockUser(db, 'lea', 'kim')).state, 'declined');
  assert.equal((await sendRequest(db, 'kim', 'lea')).state, 'pending');
});

test('blocking a stranger creates the blocked pair', async () => {
  await blockUser(db, 'max', 'ned');
  const data = (await db.doc(`friendships/${pairId('max', 'ned')}`).get()).data()!;
  assert.deepEqual(data.member_uids, ['max', 'ned']);
  assert.equal(data.state, 'blocked');
});
