import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// reCAPTCHA Enterprise site key for web, passed at build time:
/// `flutter build web --dart-define=APP_CHECK_WEB_KEY=...`.
const String appCheckWebSiteKey = String.fromEnvironment('APP_CHECK_WEB_KEY');

/// Why App Check stays off for this run, or null when it should activate.
@visibleForTesting
String? appCheckSkipReason({
  required bool usesEmulators,
  required bool isWeb,
  required String webSiteKey,
}) {
  // The emulators accept every call; a provider would only add noise.
  if (usesEmulators) return 'emulators';
  if (isWeb && webSiteKey.isEmpty) return 'missing APP_CHECK_WEB_KEY';
  return null;
}

/// Attaches App Check tokens to Firestore, Storage and Functions calls.
///
/// Activation alone rejects nothing: requests are only refused once
/// enforcement is switched on in the console (Firestore, Storage) and in
/// `functions/.env` (callables). Debug builds use the debug providers, whose
/// token is printed in the logs and must be registered in the console.
Future<void> activateAppCheck({required bool usesEmulators}) async {
  final skip = appCheckSkipReason(
    usesEmulators: usesEmulators,
    isWeb: kIsWeb,
    webSiteKey: appCheckWebSiteKey,
  );
  if (skip != null) {
    debugPrint('App Check not activated: $skip');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kDebugMode
          ? WebDebugProvider()
          : ReCaptchaEnterpriseProvider(appCheckWebSiteKey),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          // DeviceCheck needs no extra entitlement, unlike App Attest.
          : const AppleDeviceCheckProvider(),
    );
  } catch (error) {
    // Never block startup: unenforced backends still accept the requests.
    debugPrint('App Check activation failed: $error');
  }
}
