import {App, getApps, initializeApp} from 'firebase-admin/app';
import {Firestore, getFirestore} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {
  onDocumentCreated,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';

type Notification = {targetUid: string; title: string; body: string};

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function app(): App {
  return getApps()[0] ?? initializeApp();
}

function database(): Firestore {
  return getFirestore(app());
}

export function pingNotification(
  data: unknown,
  senderName?: string | null,
): Notification | null {
  if (typeof data !== 'object' || data === null) return null;
  const doc = data as Record<string, unknown>;
  const receiver = str(doc.receiver_id);
  if (!receiver) return null;
  if (doc.status !== 'pending') return null;
  const name = str(senderName ?? null);
  return {
    targetUid: receiver,
    title: 'Gelatino?',
    body: name
      ? `🍦 ${name} ti propone un gelato!`
      : '🍦 Qualcuno ti propone un gelato!',
  };
}

export function friendshipNotification(
  before: unknown,
  after: unknown,
): Notification | null {
  if (typeof after !== 'object' || after === null) return null;
  const doc = after as Record<string, unknown>;
  const requester = str(doc.requester_uid);
  const recipient = str(doc.recipient_uid);
  if (!requester || !recipient) return null;
  const beforeState =
    typeof before === 'object' && before !== null
      ? (before as Record<string, unknown>).state
      : null;
  // friendships docs are keyed by pairId and reused across the request
  // lifecycle, so a re-request after removal/decline is an UPDATE
  // (removed|declined -> pending), not a create. Notify on any transition
  // INTO pending, not only the very first create.
  if (doc.state === 'pending' && beforeState !== 'pending') {
    return {
      targetUid: recipient,
      title: 'Nuova richiesta di amicizia',
      body: 'Qualcuno vuole condividere un gelato con te 🍧',
    };
  }
  if (beforeState === 'pending' && doc.state === 'accepted') {
    return {
      targetUid: requester,
      title: 'Amicizia accettata',
      body: 'Ora siete amici di gelato! 🎉',
    };
  }
  return null;
}

async function resolveSenderName(
  db: Firestore,
  senderId: string,
): Promise<string | null> {
  try {
    const snapshot = await db.doc(`public_profiles/${senderId}`).get();
    return str(snapshot.data()?.display_name);
  } catch (error) {
    console.error('Failed to resolve ping sender name', {senderId, error});
    return null;
  }
}

type DeliveryResult = {error?: {code?: string; message?: string}};

/**
 * Classifies per-token FCM send results: tokens FCM reports as no longer
 * registered are returned for pruning, every other error is a failure to log.
 * Successful sends (no error) fall through to neither list. Kept pure so the
 * prune/keep decision is testable without a live FCM backend.
 */
export function classifyDelivery(
  responses: readonly DeliveryResult[],
  tokens: readonly string[],
): {
  prune: string[];
  failures: {token: string; code: string; message?: string}[];
} {
  const prune: string[] = [];
  const failures: {token: string; code: string; message?: string}[] = [];
  responses.forEach((result, index) => {
    const code = result.error?.code;
    if (!code) return;
    const token = tokens[index];
    if (token === undefined) return;
    if (code === 'messaging/registration-token-not-registered') {
      prune.push(token);
    } else {
      failures.push({token, code, message: result.error?.message});
    }
  });
  return {prune, failures};
}

async function deliver(note: Notification): Promise<void> {
  const db = database();
  try {
    const tokensSnapshot = await db
      .collection(`users/${note.targetUid}/fcm_tokens`)
      .get();
    const tokens = tokensSnapshot.docs.map((doc) => doc.id);
    if (tokens.length === 0) return;
    const response = await getMessaging(app()).sendEachForMulticast({
      tokens,
      notification: {title: note.title, body: note.body},
    });
    const {prune, failures} = classifyDelivery(response.responses, tokens);
    for (const failure of failures) {
      console.error('FCM delivery failed for token', {
        targetUid: note.targetUid,
        code: failure.code,
        message: failure.message,
      });
    }
    await Promise.all(
      prune.map((token) =>
        db.doc(`users/${note.targetUid}/fcm_tokens/${token}`).delete(),
      ),
    );
  } catch (error) {
    console.error('Failed to deliver push notification', {
      targetUid: note.targetUid,
      error,
    });
  }
}

export const onPingCreated = onDocumentCreated(
  {document: 'pings/{pingId}', region: 'europe-west1'},
  async (event) => {
    const data = event.data?.data();
    const senderId =
      typeof data === 'object' && data !== null
        ? str((data as Record<string, unknown>).sender_id)
        : null;
    const senderName = senderId
      ? await resolveSenderName(database(), senderId)
      : null;
    const note = pingNotification(data, senderName);
    if (note) await deliver(note);
  },
);

export const onFriendshipNotify = onDocumentWritten(
  {document: 'friendships/{pairId}', region: 'europe-west1'},
  async (event) => {
    const note = friendshipNotification(
      event.data?.before.exists ? event.data.before.data() : null,
      event.data?.after.exists ? event.data.after.data() : null,
    );
    if (note) await deliver(note);
  },
);
