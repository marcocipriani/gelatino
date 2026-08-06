import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../providers/auth_provider.dart';

class PushService {
  PushService(this._firestore, this._messaging);
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  // Guards against re-subscribing to onTokenRefresh on every social action;
  // a PushService instance lives for the app session (non-autoDispose
  // provider), so it can outlive a sign-out/sign-in as a different user.
  // Keyed by uid (not just "attached at all") so a stale listener bound to
  // the previous uid never keeps writing that uid's token document.
  String? _refreshListenerUid;
  StreamSubscription<String>? _refreshSubscription;

  @visibleForTesting
  bool get hasAttachedRefreshListener => _refreshListenerUid != null;

  static const _vapidKey = String.fromEnvironment(
    'GELATINO_VAPID_KEY',
    defaultValue: '<incolla la chiave della console>',
  );

  static Map<String, Object> tokenPayload({required String platform}) => {
    'platform': platform,
    'updated_at': FieldValue.serverTimestamp(),
  };

  /// Chiedi permesso + salva token. Chiamare SOLO dopo un'azione sociale
  /// (primo "Gelatino?" inviato, prima richiesta di amicizia) — mai a freddo.
  Future<void> enableAfterSocialAction(String uid) async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? _vapidKey : null,
    );
    if (token == null) return;
    await _saveToken(uid, token);
    attachRefreshListenerOnce(uid);
  }

  /// Subscribes to onTokenRefresh at most once per uid. Public (but
  /// `@visibleForTesting`) only so the guard can be exercised directly in
  /// tests without driving the full permission/token round trip.
  @visibleForTesting
  void attachRefreshListenerOnce(String uid) {
    if (_refreshListenerUid == uid) return;
    unawaited(_refreshSubscription?.cancel());
    _refreshListenerUid = uid;
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (fresh) => _saveToken(uid, fresh),
    );
  }

  Future<void> _saveToken(String uid, String token) {
    final platform = kIsWeb
        ? 'web'
        : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    return _firestore
        .doc('users/$uid/fcm_tokens/$token')
        .set(tokenPayload(platform: platform));
  }

  Future<void> clearForSignOut(String uid) async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _refreshListenerUid = null;

    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.doc('users/$uid/fcm_tokens/$token').delete();
    }
    await _messaging.deleteToken();
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(firestoreProvider), FirebaseMessaging.instance),
);

/// Fire-and-forget hook for social-action call sites (ping sent, friend
/// request sent). Permission denial or token failure must never break the
/// social action that triggered it, so errors are swallowed and logged.
///
/// The whole body is wrapped, not just the returned Future: `ref.read(
/// pushServiceProvider)` itself can throw synchronously (e.g. no default
/// Firebase app yet), and that throw happens outside any `unawaited`/
/// `catchError` scope — left unguarded it escapes into the caller's async
/// body and fails the social action's own Future.
void enablePushAfterSocialAction(Ref ref) {
  try {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    unawaited(
      ref.read(pushServiceProvider).enableAfterSocialAction(uid).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('PushService.enableAfterSocialAction failed: $error');
      }),
    );
  } catch (error) {
    debugPrint('PushService.enableAfterSocialAction failed: $error');
  }
}
