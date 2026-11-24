import assert from 'node:assert/strict';
import test from 'node:test';
import * as exported from '../../src/index';
import {appCheckEnforced} from '../../src/callable/options';
import {signedInRecently} from '../../src/callable/account';
import {
  parseClientFailureReport,
  underBudget,
} from '../../src/callable/telemetry';

test('exports the complete trusted API', () => {
  assert.deepEqual(
    Object.keys(exported).sort(),
    [
      'blockUser',
      'cleanupAbandonedMedia',
      'createCheckIn',
      'deleteAccount',
      'deleteCheckIn',
      'onCheckInCreated',
      'onCheckInDeleted',
      'onFriendshipChanged',
      'onFriendshipNotify',
      'onPingCreated',
      'onUserChanged',
      'removeFriendship',
      'reportClientFailure',
      'respondToFriendRequest',
      'sendFriendRequest',
      'unblockUser',
    ],
  );
});

test('App Check enforcement is opt-in through ENFORCE_APP_CHECK', () => {
  assert.equal(appCheckEnforced({}), false);
  assert.equal(appCheckEnforced({ENFORCE_APP_CHECK: 'false'}), false);
  assert.equal(appCheckEnforced({ENFORCE_APP_CHECK: 'true'}), true);
});

test('client failure reports accept only the bounded shape', () => {
  assert.deepEqual(
    parseClientFailureReport({kind: 'media_load', code: 'unauthorized', platform: 'web'}),
    {kind: 'media_load', code: 'unauthorized', platform: 'web'},
  );
  assert.equal(
    parseClientFailureReport({kind: 'uncaught_error', code: 'unknown', platform: 'web'}).kind,
    'uncaught_error',
  );
  for (const bad of [
    null,
    {kind: 'other', code: 'x', platform: 'web'},
    {kind: 'media_load', code: 'Has Spaces', platform: 'web'},
    {kind: 'media_load', code: 'x', platform: 'web', path: 'check_ins/a'},
  ]) {
    assert.throws(() => parseClientFailureReport(bad));
  }
  const counts = new Map<string, number>();
  const results = Array.from({length: 51}, () => underBudget('alice', counts));
  assert.equal(results.filter(Boolean).length, 50);
});

test('account deletion requires a sign-in from the last five minutes', () => {
  assert.equal(signedInRecently(1000, 1000 + 299), true);
  assert.equal(signedInRecently(1000, 1000 + 301), false);
  assert.equal(signedInRecently(undefined, 1000), false);
});
