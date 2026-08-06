import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/firebase/emulator_config.dart';

void main() {
  group('Firebase emulator configuration', () {
    test('is enabled only by the explicit debug define', () {
      expect(
        shouldUseFirebaseEmulators(isDebug: true, defineValue: true),
        isTrue,
      );
      expect(
        shouldUseFirebaseEmulators(isDebug: true, defineValue: false),
        isFalse,
      );
      expect(
        shouldUseFirebaseEmulators(isDebug: false, defineValue: true),
        isFalse,
      );
      expect(
        shouldUseFirebaseEmulators(isDebug: false, defineValue: false),
        isFalse,
      );
    });

    test('configure API does not expose runtime guard overrides', () {
      final source = File(
        'lib/firebase/emulator_config.dart',
      ).readAsStringSync();
      final parameters = RegExp(
        r'Future<void> configureFirebaseEmulators\(\{([\s\S]*?)\n\}\) async \{',
      ).firstMatch(source)?.group(1);

      expect(parameters, isNotNull);
      expect(parameters, isNot(contains('isDebug')));
      expect(parameters, isNot(contains('defineValue')));
      expect(
        source,
        contains(
          RegExp(
            r'shouldUseFirebaseEmulators\(\s*'
            r'isDebug: kDebugMode,\s*'
            r'defineValue: const bool\.fromEnvironment\('
            r"\s*'USE_FIREBASE_EMULATORS'\s*\)",
          ),
        ),
      );
    });

    test('debug emulator options use only the local demo project', () {
      const production = FirebaseOptions(
        apiKey: 'production-api-key',
        appId: 'production-app-id',
        messagingSenderId: 'production-sender',
        projectId: 'production-project',
        authDomain: 'production.example',
        storageBucket: 'production.appspot.com',
      );

      final emulator = firebaseOptionsForRuntime(
        base: production,
        isDebug: true,
        useFirebaseEmulators: true,
      );
      expect(emulator.projectId, 'demo-gelatino');
      expect(emulator.authDomain, 'demo-gelatino.firebaseapp.com');
      expect(emulator.storageBucket, 'demo-gelatino.appspot.com');
      expect(emulator.apiKey, production.apiKey);
      expect(emulator.appId, production.appId);
      expect(emulator.messagingSenderId, production.messagingSenderId);

      expect(
        firebaseOptionsForRuntime(
          base: production,
          isDebug: false,
          useFirebaseEmulators: true,
        ),
        same(production),
      );
      expect(
        firebaseOptionsForRuntime(
          base: production,
          isDebug: true,
          useFirebaseEmulators: false,
        ),
        same(production),
      );
    });

    test('main derives emulator-safe options before Firebase initialization', () {
      final source = File('lib/main.dart').readAsStringSync();
      final derive = source.indexOf('firebaseOptionsForRuntime(');
      final initialize = source.indexOf('Firebase.initializeApp(');

      expect(derive, greaterThanOrEqualTo(0));
      expect(initialize, greaterThan(derive));
      expect(
        source,
        contains(
          "useFirebaseEmulators: const bool.fromEnvironment('USE_FIREBASE_EMULATORS')",
        ),
      );
    });
  });
}
