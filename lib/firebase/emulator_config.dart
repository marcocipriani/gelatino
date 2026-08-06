import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const _emulatorHost = 'localhost';
const _authEmulatorPort = 9099;
const _firestoreEmulatorPort = 8080;
const _functionsEmulatorPort = 5001;
const _storageEmulatorPort = 9199;
const emulatorFirebaseProjectId = 'demo-gelatino';

bool shouldUseFirebaseEmulators({
  required bool isDebug,
  required bool defineValue,
}) {
  return isDebug && defineValue;
}

FirebaseOptions firebaseOptionsForRuntime({
  required FirebaseOptions base,
  required bool isDebug,
  required bool useFirebaseEmulators,
}) {
  if (!shouldUseFirebaseEmulators(
    isDebug: isDebug,
    defineValue: useFirebaseEmulators,
  )) {
    return base;
  }
  return base.copyWith(
    projectId: emulatorFirebaseProjectId,
    authDomain: '$emulatorFirebaseProjectId.firebaseapp.com',
    storageBucket: '$emulatorFirebaseProjectId.appspot.com',
  );
}

Future<void> configureFirebaseEmulators({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
  required FirebaseFunctions functions,
  required FirebaseStorage storage,
}) async {
  if (!shouldUseFirebaseEmulators(
    isDebug: kDebugMode,
    defineValue: const bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
  )) {
    return;
  }

  // FlutterFire makes repeated emulator setup safe across hot restarts: Auth
  // and Firestore tolerate already-configured web instances, Storage guards
  // repeated setup, and Functions deterministically replaces its origin.
  // Replay every setter so a partially failed bootstrap retries the full set.
  await auth.useAuthEmulator(_emulatorHost, _authEmulatorPort);
  firestore.useFirestoreEmulator(_emulatorHost, _firestoreEmulatorPort);
  functions.useFunctionsEmulator(_emulatorHost, _functionsEmulatorPort);
  await storage.useStorageEmulator(_emulatorHost, _storageEmulatorPort);
}
