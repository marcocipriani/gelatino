import assert from 'node:assert/strict';
import test from 'node:test';

import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';

import {seedE2E} from '../seed/e2e_seed';

test('seed removes only E2E journey artifacts and recreates its dataset', async () => {
  await seedE2E();
  const firestore = getFirestore();
  const writes = firestore.batch();
  const e2eArtifacts = [
    'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
    'friend_access/e2e-alice/members/e2e-bob',
    'users/e2e-alice/place_states/e2e-place-1',
    'feeds/e2e-alice/items/e2e-check-in',
    'pings/e2e-ping',
    'check_in_accounting/e2e-check-in',
    'check_in_tombstones/e2e-check-in',
    'check_in_projection_states/e2e-check-in',
    'event_receipts/e2e-receipt',
    'place_aggregates/e2e-place-1',
  ] as const;
  for (const path of e2eArtifacts) {
    const data = path.startsWith('friendships/') || path.startsWith('pings/')
      ? {member_uids: ['e2e-alice', 'e2e-bob']}
      : path.startsWith('check_in_accounting/')
        ? {author_uid: 'e2e-alice'}
        : path.startsWith('check_in_tombstones/')
          ? {owner_uid: 'e2e-alice'}
          : path.startsWith('check_in_projection_states/')
            ? {author_uid: 'e2e-alice', state: 'deleted'}
            : path.startsWith('event_receipts/')
              ? {check_in_id: 'e2e-check-in'}
              : {marker: 'e2e'};
    writes.set(firestore.doc(path), data);
  }
  const controlPaths = [
    'users/control-user',
    'friendships/control-pair',
    'event_receipts/control-receipt',
    'place_aggregates/control-place',
  ] as const;
  for (const path of controlPaths) {
    writes.set(firestore.doc(path), {marker: 'control'});
  }
  await writes.commit();

  const bucket = getStorage().bucket('demo-gelatino.appspot.com');
  await bucket.file('staging/e2e-alice/old.jpg').save(Buffer.from('e2e'));
  await bucket.file('staging/control-user/keep.jpg').save(Buffer.from('control'));

  await seedE2E();

  for (const path of e2eArtifacts) {
    assert.equal((await firestore.doc(path).get()).exists, false, path);
  }
  for (const path of controlPaths) {
    assert.equal((await firestore.doc(path).get()).get('marker'), 'control', path);
  }
  for (const path of [
    'users/e2e-alice',
    'users/e2e-bob',
    'public_profiles/e2e-alice',
    'public_profiles/e2e-bob',
    'places/e2e-place-1',
  ]) {
    assert.equal((await firestore.doc(path).get()).exists, true, path);
  }
  assert.equal((await bucket.file('staging/e2e-alice/old.jpg').exists())[0], false);
  assert.equal((await bucket.file('staging/control-user/keep.jpg').exists())[0], true);
  assert.equal(
    (await getAuth().getUser('e2e-alice')).email,
    'e2e-alice@example.test',
  );
});
