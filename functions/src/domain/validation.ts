import type {CreateCheckInInput} from './contracts';
import {stagingPhotoPath} from './ids';

const REQUIRED_KEYS = [
  'checkInId',
  'placeId',
  'gelatoTypeId',
  'flavorIds',
  'rating',
  'reviewText',
  'taggedUserIds',
  'stagingObjectPath',
] as const;

/// Absent means "eaten now". Older clients never send it, so it cannot be
/// required without breaking them.
const OPTIONAL_KEYS = ['consumedAtMs'] as const;

const CONTRACT_KEYS = [...REQUIRED_KEYS, ...OPTIONAL_KEYS] as const;

const CHECK_IN_ID_PATTERN = /^[A-Za-z0-9_-]{20,64}$/;

/// A backdated check-in may not sit in the future beyond plausible device clock
/// skew, and may not predate a window that keeps the feed and the scoring
/// counters meaningful.
const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
const MAX_BACKDATE_MS = 5 * 365 * 24 * 60 * 60 * 1000;

function fail(field: string, reason: string): never {
  throw new Error(`${field}: ${reason}`);
}

function trimmedId(value: unknown, field: string): string {
  if (typeof value !== 'string') fail(field, 'must be a string');

  const trimmed = value.trim();
  if (trimmed.length === 0) fail(field, 'must not be empty');
  if (trimmed.length > 128) fail(field, 'must be at most 128 characters');
  return trimmed;
}

function idArray(value: unknown, field: string, minimum: number, maximum: number): string[] {
  if (!Array.isArray(value)) fail(field, 'must be an array');
  if (value.length < minimum || value.length > maximum) {
    fail(field, `must contain between ${minimum} and ${maximum} values`);
  }

  const ids = value.map((item) => trimmedId(item, field));
  if (new Set(ids).size !== ids.length) fail(field, 'must contain unique values');
  return ids;
}

function inputObject(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Object.getPrototypeOf(value) !== Object.prototype) {
    fail('input', 'must be a plain object');
  }

  const input = value as Record<string, unknown>;
  const keys = Object.keys(input);
  const unexpectedKey = keys.find(
    (key) => !CONTRACT_KEYS.includes(key as (typeof CONTRACT_KEYS)[number]),
  );
  if (unexpectedKey !== undefined) fail(unexpectedKey, 'is not allowed');
  const missingKey = REQUIRED_KEYS.find((key) => !keys.includes(key));
  if (missingKey !== undefined) fail('input', 'must contain all contract fields');
  return input;
}

function optionalConsumedAtMs(value: unknown, now: number): number | undefined {
  if (value === undefined) return undefined;
  if (!Number.isSafeInteger(value)) {
    fail('consumedAtMs', 'must be an integer number of milliseconds');
  }
  const consumedAtMs = value as number;
  if (consumedAtMs > now + MAX_CLOCK_SKEW_MS) {
    fail('consumedAtMs', 'must not be in the future');
  }
  if (consumedAtMs < now - MAX_BACKDATE_MS) {
    fail('consumedAtMs', 'must not be more than 5 years in the past');
  }
  return consumedAtMs;
}

export function validateCreateCheckInInput(value: unknown, uid: string): CreateCheckInInput {
  const input = inputObject(value);
  const callerUid = trimmedId(uid, 'uid');
  const checkInId = trimmedId(input.checkInId, 'checkInId');
  if (!CHECK_IN_ID_PATTERN.test(checkInId)) {
    fail('checkInId', 'must be 20 to 64 URL-safe characters');
  }

  const placeId = trimmedId(input.placeId, 'placeId');
  const gelatoTypeId = trimmedId(input.gelatoTypeId, 'gelatoTypeId');
  const flavorIds = idArray(input.flavorIds, 'flavorIds', 1, 4);

  if (!Number.isInteger(input.rating) || (input.rating as number) < 1 || (input.rating as number) > 5) {
    fail('rating', 'must be an integer from 1 through 5');
  }

  if (typeof input.reviewText !== 'string') fail('reviewText', 'must be a string');
  const reviewText = input.reviewText.trim();
  if (reviewText.length > 500) fail('reviewText', 'must be at most 500 characters');

  const taggedUserIds = idArray(input.taggedUserIds, 'taggedUserIds', 0, 10);
  if (taggedUserIds.includes(callerUid)) fail('taggedUserIds', 'must not contain the caller');

  if (typeof input.stagingObjectPath !== 'string') {
    fail('stagingObjectPath', 'must be a string');
  }
  const stagingObjectPath = input.stagingObjectPath.trim();
  if (stagingObjectPath !== stagingPhotoPath(callerUid, checkInId)) {
    fail('stagingObjectPath', 'must match the caller and check-in');
  }

  const consumedAtMs = optionalConsumedAtMs(input.consumedAtMs, Date.now());

  Object.freeze(flavorIds);
  Object.freeze(taggedUserIds);
  return Object.freeze({
    checkInId,
    placeId,
    gelatoTypeId,
    flavorIds,
    rating: input.rating as number,
    reviewText,
    taggedUserIds,
    stagingObjectPath,
    ...(consumedAtMs === undefined ? {} : {consumedAtMs}),
  });
}
