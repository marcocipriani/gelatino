import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import {toPublicProfile} from '../../src/triggers/profile_sync';

const now = Timestamp.fromMillis(1_750_000_000_000);

function privateUser(overrides: Record<string, unknown> = {}) {
  return {
    display_name: 'Alice',
    display_name_lower: 'alice',
    username: 'alice-gelato',
    username_lower: 'alice-gelato',
    avatar_path: 'avatars/alice/1.jpg',
    bio: 'Pistacchio prima di tutto',
    city: 'Roma',
    favorite_place_id: 'place-1',
    favorite_flavor_id: 'pistacchio',
    favorite_flavor_ids: ['pistacchio', 'crema'],
    profile_visibility: 'friends',
    searchable: false,
    points: 42,
    email: 'alice@example.test',
    notifications_enabled: true,
    affinity: {bob: 999},
    theme_mode: 'dark',
    ...overrides,
  };
}

test('toPublicProfile returns the exact public allowlist', () => {
  const projected = toPublicProfile('alice', privateUser(), now);

  assert.deepEqual(Object.keys(projected).sort(), [
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
  assert.deepEqual(projected, {
    uid: 'alice',
    display_name: 'Alice',
    display_name_lower: 'alice',
    username: 'alice-gelato',
    username_lower: 'alice-gelato',
    avatar_path: 'avatars/alice/1.jpg',
    bio: 'Pistacchio prima di tutto',
    city: 'Roma',
    favorite_place_id: 'place-1',
    favorite_flavor_id: 'pistacchio',
    favorite_flavor_ids: ['pistacchio', 'crema'],
    profile_visibility: 'friends',
    searchable: false,
    points: 42,
    monthly_points: {},
    updated_at: now,
  });
  assert.equal(Object.isFrozen(projected), true);
  assert.equal(Object.isFrozen(projected.favorite_flavor_ids), true);
});

test('toPublicProfile rejects corrupt authoritative fields', () => {
  assert.throws(
    () => toPublicProfile('alice', privateUser({points: 2 ** 53}), now),
    /points/,
  );
  assert.throws(
    () => toPublicProfile('alice', privateUser({searchable: 'yes'}), now),
    /searchable/,
  );
  assert.throws(
    () => toPublicProfile('../alice', privateUser(), now),
    /uid/,
  );
});

test('toPublicProfile derives search keys from Rules-compatible fields', () => {
  const projected = toPublicProfile('alice', {
    display_name: 'ÀLICE Gelato',
    username: 'Alice_Cono',
    points: 0,
    affinity: {},
  }, now);

  assert.equal(projected.display_name, 'ÀLICE Gelato');
  assert.equal(projected.display_name_lower, 'àlice gelato');
  assert.equal(projected.username, 'Alice_Cono');
  assert.equal(projected.username_lower, 'alice_cono');
  assert.equal(projected.profile_visibility, 'private');
  assert.equal(projected.searchable, false);
});

test('toPublicProfile uses privacy-safe defaults for a minimal Rules payload', () => {
  assert.deepEqual(toPublicProfile('alice', {points: 0, affinity: {}}, now), {
    uid: 'alice',
    display_name: '',
    display_name_lower: '',
    username: '',
    username_lower: '',
    avatar_path: null,
    bio: '',
    city: '',
    favorite_place_id: null,
    favorite_flavor_id: null,
    favorite_flavor_ids: [],
    profile_visibility: 'private',
    searchable: false,
    points: 0,
    monthly_points: {},
    updated_at: now,
  });
});

test('monthly_points is mirrored and defaults to empty', () => {
  const withPoints = toPublicProfile(
    'u1',
    {...privateUser(), monthly_points: {'2026-07': 25}},
    now,
  );
  assert.deepEqual(withPoints.monthly_points, {'2026-07': 25});
  const without = toPublicProfile('u1', privateUser(), now);
  assert.deepEqual(without.monthly_points, {});
});

test('invalid monthly_points is rejected', () => {
  for (const bad of [
    {'2026-7': 1},        // chiave non yyyy-MM
    {'2026-07': -1},      // negativo
    {'2026-07': 1.5},     // non intero
    ['nope'],             // non oggetto
  ]) {
    assert.throws(
      () => toPublicProfile('u1', {...privateUser(), monthly_points: bad}, now),
      /monthly_points/,
    );
  }
});
