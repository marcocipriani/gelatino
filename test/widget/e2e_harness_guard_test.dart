import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/e2e/e2e_config.dart';
import 'package:gelatino/screens/check_in/photo_step.dart';
import 'package:gelatino/screens/login_screen.dart';

void main() {
  testWidgets('normal builds expose no emulator-only controls', (tester) async {
    expect(e2eTestingEnabled, isFalse);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Accedi come Alice E2E'), findsNothing);
    expect(find.text('Accedi come Bob E2E'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoStep(
            bytes: null,
            hasStagedPhoto: false,
            isUploading: false,
            photoMissing: false,
            uploadFailed: false,
            onCamera: () {},
            onGallery: () {},
            onRemove: () {},
            onRetry: () {},
            onRetryUpload: () {},
          ),
        ),
      ),
    );
    expect(find.text('Usa foto E2E'), findsNothing);
  });

  test('E2E controls fail closed outside debug emulator builds', () {
    expect(
      shouldExposeE2EControls(
        isDebug: true,
        useFirebaseEmulators: true,
        e2eTesting: true,
      ),
      isTrue,
    );
    for (final flags in <({bool debug, bool emulators, bool e2e})>[
      (debug: false, emulators: true, e2e: true),
      (debug: true, emulators: false, e2e: true),
      (debug: true, emulators: true, e2e: false),
    ]) {
      expect(
        shouldExposeE2EControls(
          isDebug: flags.debug,
          useFirebaseEmulators: flags.emulators,
          e2eTesting: flags.e2e,
        ),
        isFalse,
      );
    }
  });

  test('normal entrypoints keep E2E labels behind const-isolated modules', () {
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final photo = File(
      'lib/screens/check_in/photo_step.dart',
    ).readAsStringSync();

    expect(login, contains('if (e2eControlsEnabled)'));
    expect(photo, contains('if (e2eControlsEnabled)'));
    expect(login, isNot(contains('alice@example.test')));
    expect(login, isNot(contains('gelatino-e2e-alice')));
    expect(photo, isNot(contains('alice@example.test')));
  });
}
