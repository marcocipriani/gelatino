import assert from 'node:assert/strict';
import test from 'node:test';
import {pairId, permanentPhotoPath, stagingPhotoPath} from '../../src/domain/ids';

test('pairId is reciprocal and stable', () => {
  assert.equal(pairId('user-b', 'user-a'), 'dXNlci1h.dXNlci1i');
  assert.equal(pairId('user-a', 'user-b'), 'dXNlci1h.dXNlci1i');
});

test('photo paths are deterministic', () => {
  assert.equal(stagingPhotoPath('u1', 'ABCDEFGHIJKLMNOPQRST'), 'staging/u1/ABCDEFGHIJKLMNOPQRST.jpg');
  assert.equal(
    permanentPhotoPath('u1', 'ABCDEFGHIJKLMNOPQRST', 1),
    'check_ins/u1/ABCDEFGHIJKLMNOPQRST/1.jpg',
  );
});
