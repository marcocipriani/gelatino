import {getApps, initializeApp} from 'firebase-admin/app';
import type {Storage} from 'firebase-admin/storage';
import {getStorage} from 'firebase-admin/storage';
import {DocumentSnapshot, Firestore, getFirestore} from 'firebase-admin/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';

type StorageBucket = ReturnType<Storage['bucket']>;

const CHECK_IN_ID = /^[A-Za-z0-9_-]{20,64}$/;
const PATH_SEGMENT = /^[^/\u0000-\u001f\u007f]{1,128}$/u;
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

type PermanentCandidate = {
  file: ReturnType<StorageBucket['file']>;
  ownerUid: string;
  checkInId: string;
};

function isOld(timeCreated: unknown, cutoff: number): boolean {
  if (typeof timeCreated !== 'string') return false;
  const created = Date.parse(timeCreated);
  return Number.isFinite(created) && created < cutoff;
}

async function oldFiles(
  bucket: StorageBucket,
  prefix: string,
  cutoff: number,
) {
  const [files] = await bucket.getFiles({prefix});
  const candidates = await Promise.all(files.map(async (file) => {
    const [metadata] = await file.getMetadata();
    return isOld(metadata.timeCreated, cutoff) ? file : null;
  }));
  return candidates.filter((file): file is NonNullable<typeof file> => file !== null);
}

function permanentCandidate(
  file: ReturnType<StorageBucket['file']>,
): PermanentCandidate | null {
  const parts = file.name.split('/');
  if (
    parts.length !== 4 ||
    parts[0] !== 'check_ins' ||
    !PATH_SEGMENT.test(parts[1] ?? '') ||
    !CHECK_IN_ID.test(parts[2] ?? '') ||
    !PATH_SEGMENT.test(parts[3] ?? '')
  ) {
    return null;
  }
  return {file, ownerUid: parts[1]!, checkInId: parts[2]!};
}

function referenced(
  candidate: PermanentCandidate,
  canonical: DocumentSnapshot,
): boolean {
  return canonical.exists &&
    canonical.get('user_id') === candidate.ownerUid &&
    canonical.get('photo_storage_path') === candidate.file.name;
}

export async function cleanupMedia(
  db: Firestore,
  bucket: StorageBucket,
  now: Date,
): Promise<{deletedStaging: number; deletedPermanent: number}> {
  if (!Number.isFinite(now.getTime())) throw new Error('now: is invalid');
  const cutoff = now.getTime() - MAX_AGE_MS;
  const staging = await oldFiles(bucket, 'staging/', cutoff);
  await Promise.all(staging.map((file) => file.delete({ignoreNotFound: true})));

  const oldPermanent = await oldFiles(bucket, 'check_ins/', cutoff);
  const candidates = oldPermanent.map(permanentCandidate);
  const validCandidates = candidates.filter(
    (candidate): candidate is PermanentCandidate => candidate !== null,
  );
  const canonicalById = new Map<string, DocumentSnapshot>();
  if (validCandidates.length > 0) {
    const ids = [...new Set(validCandidates.map((candidate) => candidate.checkInId))];
    const snapshots = await db.getAll(
      ...ids.map((id) => db.doc(`check_ins/${id}`)),
    );
    ids.forEach((id, index) => canonicalById.set(id, snapshots[index]!));
  }

  const permanentToDelete = oldPermanent.filter((file, index) => {
    const candidate = candidates[index];
    if (!candidate) return true;
    const canonical = canonicalById.get(candidate.checkInId);
    return !canonical || !referenced(candidate, canonical);
  });
  await Promise.all(
    permanentToDelete.map((file) => file.delete({ignoreNotFound: true})),
  );
  return {
    deletedStaging: staging.length,
    deletedPermanent: permanentToDelete.length,
  };
}

function services(): {db: Firestore; bucket: StorageBucket} {
  const app = getApps()[0] ?? initializeApp();
  return {db: getFirestore(app), bucket: getStorage(app).bucket()};
}

export const cleanupAbandonedMedia = onSchedule(
  {
    schedule: 'every 24 hours',
    region: 'europe-west1',
    timeZone: 'Europe/Rome',
  },
  async () => {
    const {db, bucket} = services();
    await cleanupMedia(db, bucket, new Date());
  },
);
