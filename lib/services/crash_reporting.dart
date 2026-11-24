import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'media_telemetry.dart';

/// Sends uncaught errors to Crashlytics on Android and iOS. Crashlytics has no
/// web SDK, so on the web they go to [webTelemetry] (the `reportClientFailure`
/// callable), which logs only a short code, never the message or the stack.
/// Debug builds report nothing and keep Flutter's console output.
void installCrashReporting(MediaTelemetry webTelemetry) {
  if (kDebugMode) return;
  if (kIsWeb) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      webTelemetry.report(MediaFailureKind.uncaught, details.exception);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      webTelemetry.report(MediaFailureKind.uncaught, error);
      return true;
    };
    return;
  }
  final crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
