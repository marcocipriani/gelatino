#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

: "${FIRESTORE_EMULATOR_HOST:?FIRESTORE_EMULATOR_HOST is required}"
: "${FIREBASE_AUTH_EMULATOR_HOST:?FIREBASE_AUTH_EMULATOR_HOST is required}"
: "${FIREBASE_STORAGE_EMULATOR_HOST:?FIREBASE_STORAGE_EMULATOR_HOST is required}"

npm --prefix functions run seed:e2e

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/two_user_journey_test.dart \
  -d web-server \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=E2E_TESTING=true
