import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {
  RulesTestEnvironment,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {FirebaseApp, deleteApp, initializeApp} from 'firebase/app';
import {
  Auth,
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {Firestore, doc, setDoc} from 'firebase/firestore';
import {
  FirebaseStorage,
  connectStorageEmulator,
  getStorage,
} from 'firebase/storage';
import {
  App as AdminApp,
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {
  Firestore as AdminFirestore,
  getFirestore as getAdminFirestore,
} from 'firebase-admin/firestore';
import {getStorage as getAdminStorage} from 'firebase-admin/storage';

export const PROJECT_ID = 'demo-gelatino';
export const STORAGE_BUCKET = `${PROJECT_ID}.appspot.com`;

const PASSWORD = 'rules-test-password';
const USER_IDS = ['alice', 'bob', 'charlie'] as const;

type UserId = (typeof USER_IDS)[number];

export type StorageUser = {
  app: FirebaseApp;
  auth: Auth;
  storage: FirebaseStorage;
};

export type StoredObjectMetadata = {
  contentType?: string;
  metadata?: Record<string, string | number | boolean | null>;
};

export type RulesHarness = {
  adminApp: AdminApp;
  environment: RulesTestEnvironment;
  aliceDb: Firestore;
  bobDb: Firestore;
  charlieDb: Firestore;
  storageUsers: Record<UserId, StorageUser>;
  clearFirestore(): Promise<void>;
  seed(path: string, data: Record<string, unknown>): Promise<void>;
  seedStorage(
    path: string,
    data?: Uint8Array,
    contentType?: string,
  ): Promise<void>;
  storageExists(path: string): Promise<boolean>;
  storageMetadata(path: string): Promise<StoredObjectMetadata>;
  deleteStorage(path: string): Promise<void>;
  cleanup(): Promise<void>;
};

function emulatorAddress(value: string | undefined, fallbackPort: number) {
  const address = value ?? `127.0.0.1:${fallbackPort}`;
  const separator = address.lastIndexOf(':');
  if (separator < 1) throw new Error(`Invalid emulator address: ${address}`);
  return {
    host: address.slice(0, separator),
    port: Number(address.slice(separator + 1)),
  };
}

const poll = () => new Promise<void>((resolvePromise) => {
  setTimeout(resolvePromise, 50);
});

async function firestoreHasDocuments(db: AdminFirestore): Promise<boolean> {
  const rootCollections = await db.listCollections();
  const rootSnapshots = await Promise.all(
    rootCollections.map((collection) => collection.limit(1).get()),
  );
  if (rootSnapshots.some((snapshot) => !snapshot.empty)) return true;

  const nestedSnapshots = await Promise.all(
    ['items', 'members'].map((collectionId) =>
      db.collectionGroup(collectionId).limit(1).get(),
    ),
  );
  return nestedSnapshots.some((snapshot) => !snapshot.empty);
}

async function clearFirestoreWithBackgroundTriggers(
  environment: RulesTestEnvironment,
  db: AdminFirestore,
): Promise<void> {
  const deadline = Date.now() + 5_000;
  const clearWithRetry = async (): Promise<void> => {
    while (Date.now() < deadline) {
      try {
        await environment.clearFirestore();
        return;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (!message.includes('Transaction lock timeout')) throw error;
        await poll();
      }
    }
    throw new Error('Timed out clearing Firestore after background triggers');
  };

  await clearWithRetry();
  let consecutiveEmptySamples = 0;
  while (Date.now() < deadline) {
    if (await firestoreHasDocuments(db)) {
      consecutiveEmptySamples = 0;
      await clearWithRetry();
    } else {
      consecutiveEmptySamples += 1;
      if (consecutiveEmptySamples === 5) return;
    }
    await poll();
  }
  throw new Error('Firestore did not remain empty after background triggers');
}

async function createStorageUser(uid: UserId): Promise<StorageUser> {
  const app = initializeApp(
    {
      apiKey: 'demo-key',
      appId: `rules-test-${uid}`,
      authDomain: `${PROJECT_ID}.firebaseapp.com`,
      projectId: PROJECT_ID,
      storageBucket: STORAGE_BUCKET,
    },
    `rules-test-${uid}`,
  );
  const auth = getAuth(app);
  const authAddress = emulatorAddress(
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
    9099,
  );
  connectAuthEmulator(
    auth,
    `http://${authAddress.host}:${authAddress.port}`,
    {disableWarnings: true},
  );
  await signInWithEmailAndPassword(auth, `${uid}@example.test`, PASSWORD);

  const storage = getStorage(app, `gs://${STORAGE_BUCKET}`);
  const storageAddress = emulatorAddress(
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
    9199,
  );
  connectStorageEmulator(storage, storageAddress.host, storageAddress.port);
  return {app, auth, storage};
}

async function createDeterministicUsers(adminApp: AdminApp): Promise<void> {
  const auth = getAdminAuth(adminApp);
  await Promise.all(
    USER_IDS.map(async (uid) => {
      const properties = {
        email: `${uid}@example.test`,
        password: PASSWORD,
      };
      try {
        await auth.createUser({uid, ...properties});
      } catch (error) {
        const code = (error as {code?: string}).code;
        if (
          code !== 'auth/uid-already-exists' &&
          code !== 'auth/email-already-exists'
        ) {
          throw error;
        }
        await auth.updateUser(uid, properties);
      }
    }),
  );
}

export async function createRulesHarness(): Promise<RulesHarness> {
  const firestoreAddress = emulatorAddress(
    process.env.FIRESTORE_EMULATOR_HOST,
    8080,
  );
  const firestoreRules = await readFile(
    resolve(__dirname, '../../../../firestore.rules'),
    'utf8',
  );
  const environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: firestoreAddress.host,
      port: firestoreAddress.port,
      rules: firestoreRules,
    },
  });

  const adminApp = initializeAdminApp(
    {projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET},
    'rules-test-admin',
  );
  const adminDb = getAdminFirestore(adminApp);
  await createDeterministicUsers(adminApp);

  const storageUsers = {
    alice: await createStorageUser('alice'),
    bob: await createStorageUser('bob'),
    charlie: await createStorageUser('charlie'),
  };

  return {
    adminApp,
    environment,
    aliceDb: environment.authenticatedContext('alice').firestore() as unknown as Firestore,
    bobDb: environment.authenticatedContext('bob').firestore() as unknown as Firestore,
    charlieDb: environment.authenticatedContext('charlie').firestore() as unknown as Firestore,
    storageUsers,
    clearFirestore: () => clearFirestoreWithBackgroundTriggers(environment, adminDb),
    seed: (path, data) =>
      environment.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), path), data);
      }),
    seedStorage: async (
      path,
      data = new Uint8Array([1, 2, 3]),
      contentType = 'image/jpeg',
    ) => {
      await getAdminStorage(adminApp)
        .bucket(STORAGE_BUCKET)
        .file(path)
        .save(Buffer.from(data), {contentType});
    },
    storageExists: async (path) => {
      const [exists] = await getAdminStorage(adminApp)
        .bucket(STORAGE_BUCKET)
        .file(path)
        .exists();
      return exists;
    },
    storageMetadata: async (path) => {
      const [metadata] = await getAdminStorage(adminApp)
        .bucket(STORAGE_BUCKET)
        .file(path)
        .getMetadata();
      return metadata;
    },
    deleteStorage: async (path) => {
      await getAdminStorage(adminApp)
        .bucket(STORAGE_BUCKET)
        .file(path)
        .delete({ignoreNotFound: true});
    },
    cleanup: async () => {
      await environment.cleanup();
      await Promise.all(
        Object.values(storageUsers).map((user) => deleteApp(user.app)),
      );
      await deleteAdminApp(adminApp);
    },
  };
}
