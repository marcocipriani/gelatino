import assert from 'node:assert/strict';
import test from 'node:test';
import {validateCreateCheckInInput} from '../../src/domain/validation';

const valid = {
  checkInId: 'ABCDEFGHIJKLMNOPQRST',
  placeId: 'place-1',
  gelatoTypeId: 'cono',
  flavorIds: ['pistacchio'],
  rating: 5,
  reviewText: 'Molto buono',
  taggedUserIds: ['friend-1'],
  stagingObjectPath: 'staging/user-1/ABCDEFGHIJKLMNOPQRST.jpg',
};

test('accepts the complete payload', () => {
  assert.deepEqual(validateCreateCheckInInput(valid, 'user-1'), valid);
});

test('rejects a foreign staging path', () => {
  assert.throws(
    () =>
      validateCreateCheckInInput(
        {...valid, stagingObjectPath: 'staging/user-2/ABCDEFGHIJKLMNOPQRST.jpg'},
        'user-1',
      ),
    /stagingObjectPath/,
  );
});

test('consumedAtMs is optional and bounded to the past', () => {
  const hour = 60 * 60 * 1000;
  const yesterday = Date.now() - 24 * hour;

  // Omitted is the ordinary case: the server stamps publication time.
  assert.equal('consumedAtMs' in validateCreateCheckInInput(valid, 'user-1'), false);

  assert.equal(
    validateCreateCheckInInput({...valid, consumedAtMs: yesterday}, 'user-1')
      .consumedAtMs,
    yesterday,
  );

  // Small skew is tolerated so a device clock a minute fast still publishes.
  assert.equal(
    validateCreateCheckInInput(
      {...valid, consumedAtMs: Date.now() + 60 * 1000},
      'user-1',
    ).consumedAtMs !== undefined,
    true,
  );

  assert.throws(
    () =>
      validateCreateCheckInInput({...valid, consumedAtMs: Date.now() + 24 * hour}, 'user-1'),
    /consumedAtMs/,
  );
  assert.throws(
    () =>
      validateCreateCheckInInput(
        {...valid, consumedAtMs: Date.now() - 6 * 365 * 24 * hour},
        'user-1',
      ),
    /consumedAtMs/,
  );
  assert.throws(
    () => validateCreateCheckInInput({...valid, consumedAtMs: '2020-01-01'}, 'user-1'),
    /consumedAtMs/,
  );
  assert.throws(
    () => validateCreateCheckInInput({...valid, unknownField: 1}, 'user-1'),
    /unknownField/,
  );
});

test('rejects invalid cardinality and duplicate tags', () => {
  assert.throws(() => validateCreateCheckInInput({...valid, flavorIds: []}, 'user-1'), /flavorIds/);
  assert.throws(
    () => validateCreateCheckInInput({...valid, flavorIds: ['a', 'b', 'c', 'd', 'e']}, 'user-1'),
    /flavorIds/,
  );
  assert.throws(
    () =>
      validateCreateCheckInInput(
        {...valid, taggedUserIds: ['friend-1', 'friend-1']},
        'user-1',
      ),
    /taggedUserIds/,
  );
});
