import assert from 'node:assert/strict';
import {test} from 'node:test';
import {
  CHECK_IN_BASE_POINTS,
  FIRST_PLACE_BONUS,
  MIN_REPEAT_POINTS,
  SHARED_CHECK_IN_BASE_POINTS,
  TAGGED_FRIEND_AFFINITY,
  monthKey,
  pointsForParticipation,
} from '../../src/domain/scoring';

test('check-in scoring constants match the publication contract', () => {
  assert.equal(CHECK_IN_BASE_POINTS, 10);
  assert.equal(SHARED_CHECK_IN_BASE_POINTS, 15);
  assert.equal(FIRST_PLACE_BONUS, 10);
  assert.equal(MIN_REPEAT_POINTS, 2);
  assert.equal(TAGGED_FRIEND_AFFINITY, 1);
});

test('first participation adds the first-place bonus', () => {
  assert.equal(pointsForParticipation(CHECK_IN_BASE_POINTS, 0), 20);
  assert.equal(pointsForParticipation(SHARED_CHECK_IN_BASE_POINTS, 0), 25);
});

test('repeat participation decays to the minimum award', () => {
  assert.equal(pointsForParticipation(SHARED_CHECK_IN_BASE_POINTS, 1), 14);
  assert.equal(pointsForParticipation(SHARED_CHECK_IN_BASE_POINTS, 13), 2);
  assert.equal(pointsForParticipation(SHARED_CHECK_IN_BASE_POINTS, 99), 2);
});

test('monthKey is the UTC yyyy-MM of the given instant', () => {
  assert.equal(monthKey(new Date('2026-07-17T10:00:00Z')), '2026-07');
  assert.equal(monthKey(new Date('2026-01-31T23:59:59Z')), '2026-01');
  // mezzanotte UTC: il mese è quello UTC, non quello locale
  assert.equal(monthKey(new Date('2026-08-01T00:00:00Z')), '2026-08');
});
