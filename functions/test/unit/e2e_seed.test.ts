import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import test from 'node:test';

import {
  E2E_DOCUMENT_PATHS,
  E2E_JOURNEY_CLEANUP_PATHS,
  E2E_RECURSIVE_ROOTS,
  E2E_STORAGE_PREFIXES,
  assertE2ESeedEnvironment,
  buildE2ESeedDocuments,
} from '../../test/seed/e2e_seed';

const safeEnvironment = {
  GCLOUD_PROJECT: 'demo-gelatino',
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
};

test('seed accepts only demo-gelatino on the exact local emulator ports', () => {
  assert.doesNotThrow(() => assertE2ESeedEnvironment(safeEnvironment));
  assert.doesNotThrow(() =>
    assertE2ESeedEnvironment({
      ...safeEnvironment,
      GCLOUD_PROJECT: undefined,
      FIREBASE_CONFIG: JSON.stringify({projectId: 'demo-gelatino'}),
      FIRESTORE_EMULATOR_HOST: 'localhost:8080',
      FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
      FIREBASE_STORAGE_EMULATOR_HOST: 'localhost:9199',
    }),
  );

  for (const unsafe of [
    {...safeEnvironment, GCLOUD_PROJECT: 'gelatino-prod'},
    {...safeEnvironment, FIRESTORE_EMULATOR_HOST: undefined},
    {...safeEnvironment, FIRESTORE_EMULATOR_HOST: 'localhost:8081'},
    {...safeEnvironment, FIREBASE_AUTH_EMULATOR_HOST: '10.0.0.5:9099'},
    {...safeEnvironment, FIREBASE_STORAGE_EMULATOR_HOST: 'localhost:9198'},
  ]) {
    assert.throws(() => assertE2ESeedEnvironment(unsafe));
  }
});

test('seed document ownership is finite and excludes journey artifacts', () => {
  assert.deepEqual(E2E_DOCUMENT_PATHS, [
    'users/e2e-alice',
    'users/e2e-bob',
    'public_profiles/e2e-alice',
    'public_profiles/e2e-bob',
    'places/e2e-place-1',
    'gelato_types/cono',
    'flavors/pistacchio',
    'flavors/stracciatella',
  ]);
  assert.deepEqual(E2E_STORAGE_PREFIXES, [
    'avatars/e2e-alice/',
    'avatars/e2e-bob/',
    'staging/e2e-alice/',
    'staging/e2e-bob/',
    'check_ins/e2e-alice/',
    'check_ins/e2e-bob/',
  ]);
  assert.deepEqual(E2E_RECURSIVE_ROOTS, [
    'users/e2e-alice',
    'users/e2e-bob',
    'feeds/e2e-alice',
    'feeds/e2e-bob',
    'friend_access/e2e-alice',
    'friend_access/e2e-bob',
  ]);
  assert.deepEqual(E2E_JOURNEY_CLEANUP_PATHS, [
    'friendships/ZTJlLWFsaWNl.ZTJlLWJvYg',
    'friend_access/e2e-alice/members/e2e-bob',
    'friend_access/e2e-bob/members/e2e-alice',
    'users/e2e-alice/place_states/e2e-place-1',
    'users/e2e-bob/place_states/e2e-place-1',
  ]);
  assert.equal(
    E2E_JOURNEY_CLEANUP_PATHS.some(
      (path) => !path.includes('e2e-') && !path.includes('ZTJlL'),
    ),
    false,
  );
  const seededDocuments = E2E_DOCUMENT_PATHS.join('\n');
  for (const forbidden of [
    'friendships/',
    'friend_access/',
    'place_states/',
    'check_ins/',
    'feeds/',
  ]) {
    assert.equal(seededDocuments.includes(forbidden), false);
  }
});

test('dynamic cleanup queries stay anchored to reserved E2E UIDs', () => {
  const source = readFileSync(
    join(__dirname, '../../../test/seed/e2e_seed.ts'),
    'utf8',
  );
  assert.match(source, /where\('user_id', 'in', E2E_UIDS\)/);
  assert.match(source, /where\('member_uids', 'array-contains', uid\)/);
  for (const artifact of [
    'check_in_accounting',
    'check_in_tombstones',
    'check_in_projection_states',
    'event_receipts',
    'place_aggregates/e2e-place-1',
  ]) {
    assert.equal(source.includes(artifact), true);
  }
  assert.equal(source.includes("collection('check_ins').get()"), false);
  assert.equal(source.includes("collection('pings').get()"), false);
});

test('seed document set is deterministic and stops before the UI journey', () => {
  const documents = buildE2ESeedDocuments(new Date('2026-01-02T03:04:05Z'));
  assert.deepEqual(Object.keys(documents), E2E_DOCUMENT_PATHS);
  assert.equal(documents['users/e2e-alice']?.points, 0);
  assert.equal(documents['users/e2e-bob']?.points, 0);
  assert.equal(documents['public_profiles/e2e-alice']?.profile_visibility, 'public');
  assert.equal(documents['public_profiles/e2e-alice']?.searchable, true);
  assert.equal(documents['public_profiles/e2e-bob']?.profile_visibility, 'friends');
  assert.equal(documents['public_profiles/e2e-bob']?.searchable, false);
  assert.equal(documents['places/e2e-place-1']?.name, 'Gelateria E2E');
});
