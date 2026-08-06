import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import {validateCheckIn} from '../../src/triggers/check_in_projection';

const CHECK_IN_ID = 'ABCDEFGHIJKLMNOPQRST';

function checkIn(flavors: unknown[]) {
  return {
    user_id: 'alice',
    user_snapshot: {
      display_name: 'Alice',
      username: 'alice-gelato',
      avatar_path: null,
    },
    place_id: 'place-1',
    place_snapshot: {name: 'Gelateria Uno', address: 'Via Roma 1'},
    gelato_type: {id: 'cono', name: 'Cono'},
    flavors,
    rating: 5,
    review_text: 'Delizioso',
    tagged_user_ids: [],
    photo_storage_path: `check_ins/alice/${CHECK_IN_ID}/1.jpg`,
    created_at: Timestamp.now(),
    schema_version: 2,
  };
}

function flavorsOf(projection: ReturnType<typeof validateCheckIn>) {
  return projection.feedItem.flavors as Record<string, unknown>[];
}

test('accepts a legacy flavor snapshot without color_hex', () => {
  const projection = validateCheckIn(
    CHECK_IN_ID,
    checkIn([{id: 'pistacchio', name: 'Pistacchio'}]),
  );
  assert.deepEqual(flavorsOf(projection)[0], {
    id: 'pistacchio',
    name: 'Pistacchio',
  });
});

test('accepts and retains a null color_hex', () => {
  const projection = validateCheckIn(
    CHECK_IN_ID,
    checkIn([{id: 'pistacchio', name: 'Pistacchio', color_hex: null}]),
  );
  assert.deepEqual(flavorsOf(projection)[0], {
    id: 'pistacchio',
    name: 'Pistacchio',
    color_hex: null,
  });
});

test('accepts and retains a valid color_hex', () => {
  const projection = validateCheckIn(
    CHECK_IN_ID,
    checkIn([{id: 'pistacchio', name: 'Pistacchio', color_hex: '#93C572'}]),
  );
  assert.deepEqual(flavorsOf(projection)[0], {
    id: 'pistacchio',
    name: 'Pistacchio',
    color_hex: '#93C572',
  });
});

test('rejects a malformed color_hex', () => {
  assert.throws(
    () =>
      validateCheckIn(
        CHECK_IN_ID,
        checkIn([{id: 'pistacchio', name: 'Pistacchio', color_hex: 'green'}]),
      ),
    /flavors\[0\]\.color_hex/,
  );
});

test('rejects a color_hex missing the leading hash', () => {
  assert.throws(
    () =>
      validateCheckIn(
        CHECK_IN_ID,
        checkIn([
          {id: 'pistacchio', name: 'Pistacchio', color_hex: '93C572'},
        ]),
      ),
    /flavors\[0\]\.color_hex/,
  );
});

test('rejects unexpected flavor snapshot fields', () => {
  assert.throws(
    () =>
      validateCheckIn(
        CHECK_IN_ID,
        checkIn([
          {id: 'pistacchio', name: 'Pistacchio', extra_field: 'nope'},
        ]),
      ),
    /flavors\[0\]/,
  );
});
