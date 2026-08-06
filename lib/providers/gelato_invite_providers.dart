import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/gelato_invite.dart';
import '../repositories/gelato_invite_repository.dart';
import '../services/push_service.dart';
import 'auth_provider.dart';
import 'friendship_providers.dart';

final gelatoInviteDataSourceProvider = Provider<GelatoInviteDataSource>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirestoreGelatoInviteDataSource(
    ref.watch(firestoreProvider),
    () => auth.currentUser?.uid,
  );
});

final gelatoInviteRepositoryProvider = Provider<GelatoInviteRepository>((ref) {
  return GelatoInviteRepositoryImpl(
    ref.watch(gelatoInviteDataSourceProvider),
    ref.watch(friendshipRepositoryProvider),
    () => enablePushAfterSocialAction(ref),
  );
});

final pendingIncomingGelatoInvitesForUidProvider = StreamProvider.autoDispose
    .family<List<GelatoInvite>, String>((ref, uid) {
      return ref
          .watch(gelatoInviteRepositoryProvider)
          .watchPendingIncoming(uid);
    });

final pendingIncomingGelatoInvitesProvider =
    Provider.autoDispose<AsyncValue<List<GelatoInvite>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<GelatoInvite>[]);
      final inbox = ref.watch(pendingIncomingGelatoInvitesForUidProvider(uid));
      if (inbox.isLoading) return const AsyncLoading();
      return inbox;
    });

final gelatoInviteHistoryForUidProvider = StreamProvider.autoDispose
    .family<List<GelatoInvite>, String>((ref, uid) {
      return ref.watch(gelatoInviteRepositoryProvider).watchHistory(uid);
    });

final gelatoInviteHistoryProvider =
    Provider.autoDispose<AsyncValue<List<GelatoInvite>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<GelatoInvite>[]);
      final history = ref.watch(gelatoInviteHistoryForUidProvider(uid));
      if (history.isLoading) return const AsyncLoading();
      return history;
    });

final friendsBadgeCountProvider = Provider.autoDispose<int>((ref) {
  final incomingRequests =
      ref.watch(incomingFriendRequestsProvider).value?.length ?? 0;
  final incomingInvites =
      ref.watch(pendingIncomingGelatoInvitesProvider).value?.length ?? 0;
  return incomingRequests + incomingInvites;
});
