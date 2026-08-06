import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_profile.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';
import 'profile_providers.dart';

final userProfileProvider = ownProfileProvider;

UserProfile? parseCurrentUserProfileSnapshot(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
) {
  final data = snapshot.data();
  if (!snapshot.exists || data == null) return null;
  return parseOwnProfileDocument(ProfileDocument(id: snapshot.id, data: data));
}

final otherUserProfileProvider =
    Provider.family<AsyncValue<UserProfile?>, String>((ref, userId) {
      return ref
          .watch(publicProfileProvider(userId))
          .whenData(
            (profile) =>
                profile == null ? null : _toTransitionalUserProfile(profile),
          );
    });

UserProfile _toTransitionalUserProfile(PublicProfile profile) => UserProfile(
  uid: profile.uid,
  displayName: profile.displayName,
  username: profile.username,
  bio: profile.bio,
  city: profile.city,
  avatarPath: profile.avatarPath,
  favoritePlaceId: profile.favoritePlaceId,
  favoriteFlavorId: profile.favoriteFlavorId,
  favoriteFlavorIds: profile.favoriteFlavorIds,
  points: profile.points,
  isPrivate: profile.profileVisibility == 'private',
  canonicalAvatarPathPresent: true,
  canonicalFavoritePlaceIdPresent: true,
  canonicalFavoriteFlavorIdPresent: true,
  canonicalFavoriteFlavorIdsPresent: true,
);
