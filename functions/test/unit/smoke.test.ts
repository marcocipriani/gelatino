import assert from 'node:assert/strict';
import test from 'node:test';
import * as exported from '../../src/index';

test('exports the complete trusted API', () => {
  assert.deepEqual(
    Object.keys(exported).sort(),
    [
      'cleanupAbandonedMedia',
      'createCheckIn',
      'deleteCheckIn',
      'onCheckInCreated',
      'onCheckInDeleted',
      'onFriendshipChanged',
      'onFriendshipNotify',
      'onPingCreated',
      'onUserChanged',
      'removeFriendship',
      'respondToFriendRequest',
      'sendFriendRequest',
    ],
  );
});
