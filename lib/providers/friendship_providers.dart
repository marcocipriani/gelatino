import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/friendship.dart';
import '../models/public_profile.dart';
import '../repositories/friendship_repository.dart';
import '../services/push_service.dart';
import 'auth_provider.dart';

final friendshipDataSourceProvider = Provider<FriendshipDataSource>((ref) {
  return FirebaseFriendshipDataSource(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  );
});

final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  return FriendshipRepositoryImpl(
    ref.watch(friendshipDataSourceProvider),
    () => enablePushAfterSocialAction(ref),
  );
});

final friendshipsForUidProvider = StreamProvider.autoDispose
    .family<List<Friendship>, String>((ref, uid) {
      return ref.watch(friendshipRepositoryProvider).watchForUser(uid);
    });

final friendshipsProvider = Provider.autoDispose<AsyncValue<List<Friendship>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData(<Friendship>[]);
  final relationships = ref.watch(friendshipsForUidProvider(uid));
  if (relationships.isLoading) return const AsyncLoading();
  return relationships;
});

final acceptedFriendsProvider = Provider.autoDispose<AsyncValue<List<String>>>((
  ref,
) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const AsyncData(<String>[]);
  return ref.watch(friendshipsProvider).whenData((relationships) {
    final seen = <String>{};
    return List<String>.unmodifiable(
      relationships
          .where(
            (relationship) => relationship.state == FriendshipState.accepted,
          )
          .map((relationship) => _otherUid(relationship, uid))
          .where(seen.add),
    );
  });
});

final incomingFriendRequestsProvider =
    Provider.autoDispose<AsyncValue<List<Friendship>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<Friendship>[]);
      return ref
          .watch(friendshipsProvider)
          .whenData(
            (relationships) => List<Friendship>.unmodifiable(
              relationships.where(
                (relationship) =>
                    relationship.state == FriendshipState.pending &&
                    relationship.recipientUid == uid,
              ),
            ),
          );
    });

final outgoingFriendRequestsProvider =
    Provider.autoDispose<AsyncValue<List<Friendship>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<Friendship>[]);
      return ref
          .watch(friendshipsProvider)
          .whenData(
            (relationships) => List<Friendship>.unmodifiable(
              relationships.where(
                (relationship) =>
                    relationship.state == FriendshipState.pending &&
                    relationship.requesterUid == uid,
              ),
            ),
          );
    });

final acceptedFriendProfilesForUidProvider = FutureProvider.autoDispose
    .family<List<PublicProfile>, String>((ref, uid) async {
      final relationships = await ref.watch(
        friendshipsForUidProvider(uid).future,
      );
      final acceptedUids = <String>[];
      final seen = <String>{};
      for (final relationship in relationships) {
        if (relationship.state != FriendshipState.accepted) continue;
        final otherUid = _otherUid(relationship, uid);
        if (seen.add(otherUid)) acceptedUids.add(otherUid);
      }
      return ref
          .watch(friendshipRepositoryProvider)
          .readPublicProfiles(acceptedUids);
    });

final acceptedFriendProfilesProvider =
    Provider.autoDispose<AsyncValue<List<PublicProfile>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<PublicProfile>[]);
      final profiles = ref.watch(acceptedFriendProfilesForUidProvider(uid));
      if (profiles.isLoading) return const AsyncLoading();
      return profiles;
    });

final retryFriendshipSourcesProvider = Provider<void Function()>((ref) {
  return () {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    ref.invalidate(acceptedFriendProfilesForUidProvider(uid));
    ref.invalidate(friendshipsForUidProvider(uid));
  };
});

final topAffineFriendsForUidProvider = FutureProvider.autoDispose
    .family<List<AffineFriend>, String>((ref, uid) async {
      final relationships = await ref.watch(
        friendshipsForUidProvider(uid).future,
      );
      final accepted = <String, Friendship>{};
      for (final relationship in relationships) {
        if (relationship.state != FriendshipState.accepted) continue;
        final otherUid = _otherUid(relationship, uid);
        final existing = accepted[otherUid];
        if (existing == null ||
            relationship.affinityScore > existing.affinityScore) {
          accepted[otherUid] = relationship;
        }
      }
      final ordered = accepted.entries.toList()
        ..sort((left, right) {
          final score = right.value.affinityScore.compareTo(
            left.value.affinityScore,
          );
          return score != 0 ? score : left.key.compareTo(right.key);
        });
      final profiles = await ref
          .watch(friendshipRepositoryProvider)
          .readPublicProfiles(ordered.map((entry) => entry.key).toList());
      final byUid = <String, PublicProfile>{
        for (final profile in profiles) profile.uid: profile,
      };
      return List<AffineFriend>.unmodifiable(
        ordered
            .where((entry) => byUid.containsKey(entry.key))
            .map(
              (entry) => AffineFriend(
                profile: byUid[entry.key]!,
                affinityScore: entry.value.affinityScore,
              ),
            ),
      );
    });

final topAffineFriendsProvider =
    Provider.autoDispose<AsyncValue<List<AffineFriend>>>((ref) {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const AsyncData(<AffineFriend>[]);
      final friends = ref.watch(topAffineFriendsForUidProvider(uid));
      if (friends.isLoading) return const AsyncLoading();
      return friends;
    });

final class AffineFriend {
  const AffineFriend({required this.profile, required this.affinityScore});

  final PublicProfile profile;
  final int affinityScore;
}

List<PublicProfile> sortFriendProfilesByRelationshipRecency(
  Iterable<PublicProfile> profiles,
  Iterable<Friendship> relationships,
  String uid,
) {
  final updatedAtByUid = <String, DateTime>{};
  for (final relationship in relationships) {
    if (relationship.state != FriendshipState.accepted ||
        !relationship.memberUids.contains(uid)) {
      continue;
    }
    final otherUid = _otherUid(relationship, uid);
    final existing = updatedAtByUid[otherUid];
    if (existing == null || relationship.updatedAt.isAfter(existing)) {
      updatedAtByUid[otherUid] = relationship.updatedAt;
    }
  }
  final sorted = profiles.toList()
    ..sort((left, right) {
      final leftUpdatedAt = updatedAtByUid[left.uid];
      final rightUpdatedAt = updatedAtByUid[right.uid];
      if (leftUpdatedAt == null && rightUpdatedAt != null) return 1;
      if (leftUpdatedAt != null && rightUpdatedAt == null) return -1;
      if (leftUpdatedAt != null && rightUpdatedAt != null) {
        final updatedAt = rightUpdatedAt.compareTo(leftUpdatedAt);
        if (updatedAt != 0) return updatedAt;
      }
      return left.uid.compareTo(right.uid);
    });
  return List<PublicProfile>.unmodifiable(sorted);
}

String _otherUid(Friendship relationship, String uid) =>
    relationship.memberUids.firstWhere((memberUid) => memberUid != uid);
