import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/firestore_parsing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('strict Firestore parsing', () {
    test('required values reject missing and wrong types', () {
      expect(
        () => requireString(<String, dynamic>{}, 'name'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => requireInt(<String, dynamic>{'points': 1.5}, 'points'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => requireTimestamp(<String, dynamic>{
          'created_at': '2026-07-14',
        }, 'created_at'),
        throwsA(isA<FormatException>()),
      );
    });

    test('optional values distinguish absence from malformed values', () {
      expect(optionalString(<String, dynamic>{}, 'photo_url'), isNull);
      expect(optionalTimestamp(<String, dynamic>{}, 'updated_at'), isNull);
      expect(
        optionalBool(<String, dynamic>{}, 'searchable', fallback: true),
        isTrue,
      );
      expect(
        () => optionalBool(<String, dynamic>{'searchable': null}, 'searchable'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () =>
            optionalTimestamp(<String, dynamic>{'updated_at': 0}, 'updated_at'),
        throwsA(isA<FormatException>()),
      );
    });

    test('stringList rejects mixed entries without coercion', () {
      expect(
        stringList(<String, dynamic>{
          'ids': <Object>['one', 'two'],
        }, 'ids'),
        <String>['one', 'two'],
      );
      expect(
        () => stringList(<String, dynamic>{
          'ids': <Object>['one', 2],
        }, 'ids'),
        throwsA(isA<FormatException>()),
      );
    });

    test('stringMap rejects non-string keys', () {
      expect(
        stringMap(<String, dynamic>{
          'snapshot': <String, Object>{'id': 'x'},
        }, 'snapshot'),
        <String, dynamic>{'id': 'x'},
      );
      expect(
        () => stringMap(<String, dynamic>{
          'snapshot': <Object, Object>{1: 'x'},
        }, 'snapshot'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parseOrReport reports one Flutter error with the document path', () {
      final previousHandler = FlutterError.onError;
      final reports = <FlutterErrorDetails>[];
      FlutterError.onError = reports.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      final parsed = parseOrReport<String>(
        path: 'public_profiles/user-1',
        parse: () => throw const FormatException('bad field'),
      );

      expect(parsed, isNull);
      expect(reports, hasLength(1));
      expect(reports.single.toString(), contains('public_profiles/user-1'));
    });
  });
}
