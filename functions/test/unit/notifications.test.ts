import assert from 'node:assert/strict';
import test from 'node:test';
import {
  classifyDelivery,
  friendshipNotification,
  pingNotification,
} from '../../src/triggers/notifications';

// Real ping doc shape (see lib/repositories/gelato_invite_repository.dart:201
// and firestore.rules validPingCreate) — no sender_name field.
function pingDoc(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    member_uids: ['a', 'b'],
    sender_id: 'a',
    receiver_id: 'b',
    status: 'pending',
    created_at: null,
    responded_at: null,
    ...overrides,
  };
}

test('ping creation notifies the receiver with the resolved sender name', () => {
  const note = pingNotification(pingDoc(), 'Marco');
  assert.deepEqual(note, {
    targetUid: 'b',
    title: 'Gelatino?',
    body: '🍦 Marco ti propone un gelato!',
  });
});

test('ping creation falls back to a generic body when the sender name is unresolved', () => {
  for (const senderName of [undefined, null, '']) {
    const note = pingNotification(pingDoc(), senderName);
    assert.deepEqual(note, {
      targetUid: 'b',
      title: 'Gelatino?',
      body: '🍦 Qualcuno ti propone un gelato!',
    });
  }
});

test('malformed ping docs produce no notification', () => {
  assert.equal(pingNotification({receiver_id: 42}), null);
  assert.equal(pingNotification(null), null);
});

test('non-pending pings produce no notification', () => {
  assert.equal(
    pingNotification(pingDoc({status: 'accepted'}), 'Marco'),
    null,
  );
});

test('friendship request notifies recipient, acceptance notifies requester', () => {
  const base = {requester_uid: 'a', recipient_uid: 'b'};
  assert.equal(
    friendshipNotification(null, {...base, state: 'pending'})?.targetUid,
    'b',
  );
  assert.equal(
    friendshipNotification(
      {...base, state: 'pending'},
      {...base, state: 'accepted'},
    )?.targetUid,
    'a',
  );
});

test('friendship re-requests (removed/declined -> pending) notify the recipient again', () => {
  const base = {requester_uid: 'a', recipient_uid: 'b'};
  assert.equal(
    friendshipNotification(
      {...base, state: 'removed'},
      {...base, state: 'pending'},
    )?.targetUid,
    'b',
  );
  assert.equal(
    friendshipNotification(
      {...base, state: 'declined'},
      {...base, state: 'pending'},
    )?.targetUid,
    'b',
  );
});

test('friendship writes that stay pending or leave accepted do not renotify', () => {
  const base = {requester_uid: 'a', recipient_uid: 'b'};
  // pending -> pending (e.g. unrelated field update) must not re-notify.
  assert.equal(
    friendshipNotification(
      {...base, state: 'pending'},
      {...base, state: 'pending'},
    ),
    null,
  );
  assert.equal(
    friendshipNotification(
      {...base, state: 'accepted'},
      {...base, state: 'removed'},
    ),
    null,
  );
  assert.equal(friendshipNotification(null, {...base, state: 'declined'}), null);
});

test('malformed friendship docs produce no notification', () => {
  assert.equal(friendshipNotification(null, {state: 'pending'}), null);
});

test('classifyDelivery prunes only unregistered tokens and logs other errors', () => {
  const {prune, failures} = classifyDelivery(
    [
      {}, // success -> neither pruned nor failed
      {error: {code: 'messaging/registration-token-not-registered'}},
      {error: {code: 'messaging/invalid-argument', message: 'bad token'}},
    ],
    ['tok-ok', 'tok-stale', 'tok-bad'],
  );
  // Only the unregistered token is pruned — never the valid or the
  // transiently-failing one (pruning those would silently drop a live device).
  assert.deepEqual(prune, ['tok-stale']);
  assert.deepEqual(failures, [
    {token: 'tok-bad', code: 'messaging/invalid-argument', message: 'bad token'},
  ]);
});

test('classifyDelivery keeps prune indices aligned with their tokens', () => {
  const {prune} = classifyDelivery(
    [
      {error: {code: 'messaging/registration-token-not-registered'}},
      {},
      {error: {code: 'messaging/registration-token-not-registered'}},
    ],
    ['first', 'second', 'third'],
  );
  assert.deepEqual(prune, ['first', 'third']);
});

test('classifyDelivery returns empty lists when every send succeeds', () => {
  const {prune, failures} = classifyDelivery([{}, {}], ['a', 'b']);
  assert.deepEqual(prune, []);
  assert.deepEqual(failures, []);
});
