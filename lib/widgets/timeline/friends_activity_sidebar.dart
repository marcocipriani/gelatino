import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../providers/timeline_providers.dart';
import '../avatar_image_provider.dart';
import '../editorial_card.dart';
import '../../constants/app_strings.dart';

final class FriendsActivitySidebar extends StatelessWidget {
  const FriendsActivitySidebar({
    super.key,
    required this.activities,
    required this.onRetry,
  });

  final AsyncValue<List<FriendActivity>> activities;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EditorialCard.flat(
      key: const ValueKey<String>('timeline-friends-sidebar'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppStrings.activityFromFriends,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: activities.when(
              data: (items) => items.isEmpty
                  ? const _SidebarMessage(
                      icon: Icons.people_outline,
                      text: AppStrings.activityEmptyDesc,
                    )
                  : ListView.separated(
                      key: const ValueKey<String>('timeline-friends-list'),
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _FriendActivityRow(activity: items[index]),
                    ),
              loading: () => const _SidebarLoading(),
              error: (error, stackTrace) => _SidebarError(onRetry: onRetry),
            ),
          ),
        ],
      ),
    );
  }
}

final class _FriendActivityRow extends StatelessWidget {
  const _FriendActivityRow({required this.activity});

  final FriendActivity activity;

  @override
  Widget build(BuildContext context) {
    final latest = activity.latestItem;
    final copy = latest == null
        ? AppStrings.activityEmptyTitle
        : AppStrings.activityCheckInFrom(latest.placeSnapshot['name'] as String);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AuthenticatedAvatar(
            source: activity.profile.avatarPath,
            radius: 20,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  copy,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SidebarMessage extends StatelessWidget {
  const _SidebarMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

final class _SidebarLoading extends StatelessWidget {
  const _SidebarLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 96,
    child: Center(child: CircularProgressIndicator.adaptive()),
  );
}

final class _SidebarError extends StatelessWidget {
  const _SidebarError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      const _SidebarMessage(
        icon: Icons.error_outline,
        text: AppStrings.activityUnavailable,
      ),
      TextButton(
        key: const ValueKey<String>('timeline-sidebar-retry'),
        onPressed: onRetry,
        child: const Text(AppStrings.retry),
      ),
    ],
  );
}
