import 'package:flutter/foundation.dart';

const bool e2eTestingEnabled = bool.fromEnvironment('E2E_TESTING');
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
);

bool shouldExposeE2EControls({
  required bool isDebug,
  required bool useFirebaseEmulators,
  required bool e2eTesting,
}) => isDebug && useFirebaseEmulators && e2eTesting;

const bool e2eControlsEnabled =
    kDebugMode && useFirebaseEmulators && e2eTestingEnabled;
