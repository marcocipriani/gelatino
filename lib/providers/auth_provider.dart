import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gelatino/firebase/firebase_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});

final currentUserDisplayNameProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.displayName;
});
