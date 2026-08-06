import assert from 'node:assert/strict';
import test from 'node:test';
import {
  onCheckInCreated,
} from '../../src/triggers/check_in_projection';
import {onFriendshipChanged} from '../../src/triggers/friendship_projection';
import {onUserChanged} from '../../src/triggers/profile_sync';
import {
  onFriendshipNotify,
  onPingCreated,
} from '../../src/triggers/notifications';

const CHECK_IN_ID = 'ABCDEFGHIJKLMNOPQRST';

async function withoutExpectedErrorLogs(operation: () => Promise<void>) {
  const original = console.error;
  console.error = () => undefined;
  try {
    await operation();
  } finally {
    console.error = original;
  }
}

test('Firestore wrappers terminate malformed legacy events without retrying', async () => {
  const malformedSnapshot = {
    exists: true,
    data: () => ({legacy: true}),
  };
  const missingSnapshot = {exists: false, data: () => undefined};

  await withoutExpectedErrorLogs(async () => {
    await assert.doesNotReject(
      onUserChanged.run({
        data: {after: malformedSnapshot, before: missingSnapshot},
        params: {uid: '../alice'},
        time: new Date().toISOString(),
      } as never),
    );
    await assert.doesNotReject(
      onCheckInCreated.run({
        data: malformedSnapshot,
        id: 'legacy-create-event',
        params: {checkInId: CHECK_IN_ID},
      } as never),
    );
    await assert.doesNotReject(
      onFriendshipChanged.run({
        data: {after: malformedSnapshot, before: missingSnapshot},
        params: {friendshipId: 'legacy'},
      } as never),
    );
  });
});

test('notification wrappers terminate on malformed events without delivering', async () => {
  const malformedSnapshot = {exists: true, data: () => ({legacy: true})};
  const missingSnapshot = {exists: false, data: () => undefined};

  await withoutExpectedErrorLogs(async () => {
    // Malformed ping/friendship docs make the pure notification builders
    // return null, so deliver() never runs (no Firestore/FCM reached) and the
    // wrapper must terminate without throwing or requesting a retry.
    await assert.doesNotReject(
      onPingCreated.run({
        data: malformedSnapshot,
        id: 'legacy-ping-event',
        params: {pingId: 'legacy'},
      } as never),
    );
    await assert.doesNotReject(
      onFriendshipNotify.run({
        data: {after: malformedSnapshot, before: missingSnapshot},
        params: {pairId: 'legacy'},
      } as never),
    );
  });
});
