import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase/firebase_providers.dart';

abstract interface class RouterAuthSession implements Listenable {
  String? get uid;

  Future<void> signInWithGoogle();
}

final class FirebaseRouterAuthSession extends ChangeNotifier
    implements RouterAuthSession {
  FirebaseRouterAuthSession(this._auth) {
    _subscription = _auth.authStateChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: googleAuth.idToken),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final routerAuthSessionProvider = Provider<RouterAuthSession>((ref) {
  final session = FirebaseRouterAuthSession(ref.watch(firebaseAuthProvider));
  ref.onDispose(session.dispose);
  return session;
});
