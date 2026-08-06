import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/e2e/e2e_config.dart';
import 'package:gelatino/e2e/emulator_photo_fixture.dart';
import 'package:gelatino/e2e/emulator_test_login.dart';
import 'package:gelatino/screens/check_in/photo_step.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets(
    'Alice and Bob sign in with deterministic emulator credentials',
    (tester) async {
      final auth = _RecordingAuth();
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmulatorTestLogin(
              auth: auth,
              redirect: '/join?by=bob',
              onSignedIn: (value) => destination = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Accedi come Alice E2E'));
      await tester.pumpAndSettle();
      expect(auth.email, 'alice@example.test');
      expect(auth.password, 'gelatino-e2e-alice');
      expect(destination, '/join?by=bob');

      await tester.tap(find.text('Accedi come Bob E2E'));
      await tester.pumpAndSettle();
      expect(auth.email, 'bob@example.test');
      expect(auth.password, 'gelatino-e2e-bob');
    },
    skip: !e2eControlsEnabled,
  );

  testWidgets('emulator login sanitizes hostile redirects', (tester) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmulatorTestLogin(
            auth: _RecordingAuth(),
            redirect: 'https://evil.example/steal',
            onSignedIn: (value) => destination = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Accedi come Alice E2E'));
    await tester.pumpAndSettle();
    expect(destination, '/collection');
  }, skip: !e2eControlsEnabled);

  testWidgets(
    'photo fixture control is enabled only through its callback',
    (tester) async {
      var calls = 0;
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
              onE2EPhoto: () => calls++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Usa foto E2E'));
      expect(calls, 1);
    },
    skip: !e2eControlsEnabled,
  );

  test('photo fixture is a fixed valid JPEG', () {
    expect(EmulatorPhotoFixture.fileName, endsWith('.jpg'));
    expect(
      EmulatorPhotoFixture.bytes.take(2),
      orderedEquals(<int>[0xff, 0xd8]),
    );
    expect(image.decodeJpg(EmulatorPhotoFixture.bytes), isNotNull);
  });
}

final class _RecordingAuth implements FirebaseAuth {
  String? email;
  String? password;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    return _UserCredential();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
