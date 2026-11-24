import type {Auth} from 'firebase-admin/auth';
import type {Firestore} from 'firebase-admin/firestore';
import type {Storage} from 'firebase-admin/storage';
import {logger} from 'firebase-functions';
import {deletePublishedCheckIn} from './check_ins';

type StorageBucket = ReturnType<Storage['bucket']>;

/**
 * Deletes everything that belongs to [uid], then the Auth user.
 *
 * Check-ins go through the owner deletion first, so points, visit counts and
 * friendship affinity are rolled back while the friendships still exist. The
 * existing triggers then clean up what hangs off each deletion: feed items and
 * aggregates for check-ins, friend_access edges and cross feed items for
 * friendships, the public profile for `users/{uid}`.
 *
 * Kept on purpose: places and flavors the user added (shared catalog), their
 * reports, and check-ins of friends that tagged them (the friend's content).
 *
 * Safe to retry: every step tolerates data that is already gone.
 */
export async function deleteAccountData(
  db: Firestore,
  bucket: StorageBucket,
  auth: Pick<Auth, 'deleteUser'>,
  uid: string,
): Promise<void> {
  const checkIns = await db.collection('check_ins')
    .where('user_id', '==', uid)
    .get();
  for (const checkIn of checkIns.docs) {
    try {
      await deletePublishedCheckIn(db, uid, checkIn.id);
    } catch (error) {
      // A corrupt accounting pair, or a tagged friend who already deleted
      // their account, must not block the deletion of this one.
      logger.warn('account_deletion_raw_check_in', {uid, checkInId: checkIn.id});
      await Promise.all([
        checkIn.ref.delete(),
        db.doc(`check_in_accounting/${checkIn.id}`).delete(),
      ]);
    }
  }

  const [friendships, pings] = await Promise.all([
    db.collection('friendships').where('member_uids', 'array-contains', uid).get(),
    db.collection('pings').where('member_uids', 'array-contains', uid).get(),
  ]);
  const writer = db.bulkWriter();
  for (const document of [...friendships.docs, ...pings.docs]) {
    void writer.delete(document.ref);
  }
  void writer.delete(db.doc(`public_profiles/${uid}`));
  await writer.close();

  await Promise.all([
    db.recursiveDelete(db.doc(`users/${uid}`)),
    db.recursiveDelete(db.doc(`feeds/${uid}`)),
    db.recursiveDelete(db.doc(`friend_access/${uid}`)),
  ]);

  await Promise.all(
    ['check_ins', 'staging', 'avatars'].map((folder) =>
      bucket.deleteFiles({prefix: `${folder}/${uid}/`}),
    ),
  );

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if ((error as {code?: string}).code !== 'auth/user-not-found') throw error;
  }
}
