import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/services/media_telemetry.dart';
import 'package:gelatino/services/storage_service.dart';

void main() {
  test('codes are short, path-free and never class names', () {
    expect(
      mediaFailureCode(
        FirebaseException(plugin: 'storage', code: 'unauthorized'),
      ),
      'unauthorized',
    );
    expect(
      mediaFailureCode(
        FirebaseException(plugin: 'storage', code: 'Weird Code!'),
      ),
      'weird_code_',
    );
    expect(mediaFailureCode(const StorageImageFailure()), 'invalid_image');
    expect(mediaFailureCode(TimeoutException('slow')), 'timeout');
    expect(mediaFailureCode(StateError('check_ins/alice/x')), 'unknown');
  });

  test('collapses repeats within the window and caps the session', () async {
    final sent = <Map<String, String>>[];
    var now = DateTime(2026);
    final telemetry = CallableMediaTelemetry(
      (payload) async => sent.add(payload),
      now: () => now,
      maxPerSession: 3,
    );
    final error = FirebaseException(plugin: 'storage', code: 'unauthorized');

    telemetry.report(MediaFailureKind.load, error);
    telemetry.report(MediaFailureKind.load, error);
    now = now.add(const Duration(minutes: 2));
    telemetry.report(MediaFailureKind.load, error);
    telemetry.report(MediaFailureKind.decode, error);
    telemetry.report(MediaFailureKind.upload, error);
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(3));
    expect(sent.first, <String, String>{
      'kind': 'media_load',
      'code': 'unauthorized',
      // flutter_test reports Android as the default target platform.
      'platform': 'android',
    });
  });

  test('a failing send never throws', () async {
    final telemetry = CallableMediaTelemetry(
      (_) async => throw StateError('offline'),
    );
    telemetry.report(MediaFailureKind.load, StateError('x'));
    await Future<void>.delayed(Duration.zero);
  });
}
