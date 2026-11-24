import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_service.dart';

enum MediaFailureKind {
  load('media_load'),
  decode('media_decode'),
  upload('photo_upload');

  const MediaFailureKind(this.wireName);

  final String wireName;
}

/// Reports image failures so production problems are visible at all;
/// previously they only reached `debugPrint`.
abstract interface class MediaTelemetry {
  void report(MediaFailureKind kind, Object error);
}

/// Default, so tests and code paths without Firebase report nothing.
final class NoMediaTelemetry implements MediaTelemetry {
  const NoMediaTelemetry();

  @override
  void report(MediaFailureKind kind, Object error) {}
}

/// A short, path-free code for [error]; class names are minified on web, so
/// anything unrecognised is just `unknown`.
@visibleForTesting
String mediaFailureCode(Object error) => switch (error) {
  FirebaseException(:final code) => _sanitize(code),
  StorageImageFailure() => 'invalid_image',
  TimeoutException() => 'timeout',
  FormatException() => 'invalid_path',
  _ => 'unknown',
};

String _sanitize(String code) {
  final cleaned = code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_/-]'), '_');
  if (cleaned.isEmpty) return 'unknown';
  return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
}

String _platform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}

/// Sends reports to the `reportClientFailure` callable, which writes them to
/// Cloud Logging. Identical reports within [dedupeWindow] collapse into one
/// (provider retries repeat the same failure), and a session sends at most
/// [maxPerSession]. Sending never throws.
final class CallableMediaTelemetry implements MediaTelemetry {
  CallableMediaTelemetry(
    this._send, {
    DateTime Function()? now,
    this.dedupeWindow = const Duration(minutes: 1),
    this.maxPerSession = 30,
  }) : _now = now ?? DateTime.now;

  factory CallableMediaTelemetry.forFunctions(FirebaseFunctions functions) {
    final callable = functions.httpsCallable('reportClientFailure');
    return CallableMediaTelemetry((payload) => callable.call<void>(payload));
  }

  final Future<void> Function(Map<String, String> payload) _send;
  final DateTime Function() _now;
  final Duration dedupeWindow;
  final int maxPerSession;
  final Map<String, DateTime> _lastSent = <String, DateTime>{};
  int _sent = 0;

  @override
  void report(MediaFailureKind kind, Object error) {
    final code = mediaFailureCode(error);
    final key = '${kind.wireName}:$code';
    final now = _now();
    final last = _lastSent[key];
    if (last != null && now.difference(last) < dedupeWindow) return;
    if (_sent >= maxPerSession) return;
    _lastSent[key] = now;
    _sent++;
    unawaited(
      _send(<String, String>{
        'kind': kind.wireName,
        'code': code,
        'platform': _platform(),
      }).catchError((Object sendError) {
        debugPrint('Media telemetry not sent: $sendError');
      }),
    );
  }
}

/// `main.dart` overrides this with [CallableMediaTelemetry.forFunctions].
final mediaTelemetryProvider = Provider<MediaTelemetry>(
  (ref) => const NoMediaTelemetry(),
);
