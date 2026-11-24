import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_strings.dart';
import '../../providers/profile_providers.dart';
import 'friends_sections.dart';

final class FriendsRemotePersonCard extends ConsumerWidget {
  const FriendsRemotePersonCard({
    super.key,
    required this.uid,
    required this.fallbackTitle,
    required this.actions,
    required this.onOpen,
    this.subtitle = AppStrings.profileGelatinoFallback,
    this.failure,
  });

  final String uid;
  final String fallbackTitle;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback onOpen;
  final Widget? failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(publicProfileProvider(uid))
        .when(
          data: (profile) => FriendsPersonCard(
            uid: uid,
            name: profile?.displayName ?? fallbackTitle,
            subtitle: subtitle,
            avatarPath: profile?.avatarPath,
            actions: actions,
            onOpen: onOpen,
            failure: failure,
          ),
          loading: () => const FriendsSkeleton(rows: 1),
          error: (error, stackTrace) => FriendsStatePanel(
            title: AppStrings.profileUnavailable,
            message: AppStrings.friendsPersonLoadError,
            actionLabel: AppStrings.retry,
            onAction: () => ref.invalidate(publicProfileProvider(uid)),
          ),
        );
  }
}
