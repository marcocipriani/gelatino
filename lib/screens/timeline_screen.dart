import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../providers/friendship_providers.dart';
import '../providers/timeline_providers.dart';
import '../widgets/bounce_button.dart';
import '../widgets/editorial_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/timeline/friends_activity_sidebar.dart';
import '../widgets/timeline/timeline_compact_deck.dart';
import '../widgets/timeline/timeline_editorial_card.dart';
import 'check_in_screen.dart';
import '../constants/app_strings.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelineProvider);
    final controller = ref.read(timelineProvider.notifier);
    final retryFriendshipSources = ref.read(retryFriendshipSourcesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveClass.fromWidth(constraints.maxWidth);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: _TimelineBody(
              state: state,
              responsive: responsive,
              onRefresh: controller.refresh,
              onLoadMore: controller.loadNextPage,
              friendsActivity: ref.watch(friendsActivityProvider),
              onRetryFriends: retryFriendshipSources,
            ),
          ),
          floatingActionButton:
              state.items.isNotEmpty && responsive != ResponsiveClass.compact
              ? const _CheckInAction()
              : null,
        );
      },
    );
  }
}

final class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.state,
    required this.responsive,
    required this.onRefresh,
    required this.onLoadMore,
    required this.friendsActivity,
    required this.onRetryFriends,
  });

  final TimelineState state;
  final ResponsiveClass responsive;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final AsyncValue<List<FriendActivity>> friendsActivity;
  final VoidCallback onRetryFriends;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return _TimelineLoading(responsive: responsive);
    }
    if (state.items.isEmpty) {
      if (state.failure != null) {
        return _TimelineFailure(
          message: state.failure!.message,
          onRetry: onRefresh,
        );
      }
      return _TimelineEmpty(
        emptyState: state.emptyState,
        onRefresh: onRefresh,
        onRetryFriendships: onRetryFriends,
      );
    }

    if (responsive == ResponsiveClass.compact) {
      return TimelineCompactDeck(
        items: state.items,
        hasMore: state.hasMore,
        isLoadingMore: state.isLoadingMore,
        failure: state.failure,
        onLoadMore: onLoadMore,
        onRefresh: onRefresh,
      );
    }
    if (responsive == ResponsiveClass.medium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.feed),
            child: SizedBox(
              key: const ValueKey<String>('timeline-medium-feed'),
              width: double.infinity,
              child: _TimelineScrollFeed(
                state: state,
                onRefresh: onRefresh,
                onLoadMore: onLoadMore,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = _timelineSidebarWidth(constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: AppLayout.feed + AppSpacing.xl + sidebarWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    key: const ValueKey<String>('timeline-wide-feed'),
                    width: AppLayout.feed,
                    height: constraints.maxHeight,
                    child: _TimelineScrollFeed(
                      state: state,
                      onRefresh: onRefresh,
                      onLoadMore: onLoadMore,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  SizedBox(
                    width: sidebarWidth,
                    height: constraints.maxHeight,
                    child: FriendsActivitySidebar(
                      activities: friendsActivity,
                      onRetry: onRetryFriends,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _TimelineScrollFeed extends StatelessWidget {
  const _TimelineScrollFeed({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final TimelineState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 480 &&
            state.hasMore &&
            !state.isLoadingMore) {
          unawaited(onLoadMore());
        }
        return false;
      },
      child: CustomScrollView(
        key: const ValueKey<String>('timeline-feed-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        // About two cards below the fold are built early, so their photos are
        // already loading when they scroll into view. `scrollCacheExtent` is
        // not available on the oldest Flutter this project supports (3.44).
        // ignore: deprecated_member_use
        cacheExtent: 1600,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.md,
              0,
              AppSpacing.xl,
            ),
            sliver: SliverList.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: TimelineEditorialCard(item: state.items[index]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 104),
              child: _PaginationFooter(state: state, onLoadMore: onLoadMore),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty({
    required this.emptyState,
    required this.onRefresh,
    required this.onRetryFriendships,
  });

  final TimelineEmptyState emptyState;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryFriendships;

  @override
  Widget build(BuildContext context) {
    final (title, description, actionLabel, action) = switch (emptyState) {
      TimelineEmptyState.noAcceptedFriends => (
        AppStrings.timelineNoFriendsTitle,
        AppStrings.timelineNoFriendsDesc,
        AppStrings.timelineAddFriends,
        () => context.go('/friends'),
      ),
      TimelineEmptyState.friendsWithoutActivity => (
        AppStrings.timelineNoRecentTitle,
        AppStrings.timelineNoRecentDesc,
        AppStrings.timelineCheckInButton,
        () => _openCheckIn(context),
      ),
      TimelineEmptyState.authorizationPending => (
        AppStrings.timelineFriendshipsUpdating,
        AppStrings.timelineFriendshipsUpdatingDesc,
        AppStrings.retry,
        onRetryFriendships,
      ),
      TimelineEmptyState.authorizationFailed => (
        AppStrings.timelineFriendshipsUnavailable,
        AppStrings.timelineFriendshipsUnavailableDesc,
        AppStrings.retry,
        onRetryFriendships,
      ),
      TimelineEmptyState.signedOut => (
        AppStrings.timelineLoginTitle,
        AppStrings.timelineLoginDesc,
        AppStrings.login,
        () => context.go('/login'),
      ),
      TimelineEmptyState.none => (
        AppStrings.timelineNoRecentTitle,
        AppStrings.timelineNoRecentSelfDesc,
        AppStrings.timelineCheckInButton,
        () => _openCheckIn(context),
      ),
    };
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.sizeOf(context).height - AppSpacing.display,
            child: EmptyState(
              icon: Icons.history_edu,
              title: title,
              description: description,
              action: FilledButton.tonal(
                key: ValueKey<String>(
                  'timeline-empty-${actionLabel.toLowerCase()}',
                ),
                onPressed: action,
                child: Text(actionLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _TimelineFailure extends StatelessWidget {
  const _TimelineFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            key: const ValueKey<String>('timeline-retry'),
            onPressed: () => unawaited(onRetry()),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    ),
  );
}

final class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.state, required this.onLoadMore});

  final TimelineState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (state.failure != null) {
      return Column(
        children: <Widget>[
          Text(state.failure!.message, textAlign: TextAlign.center),
          TextButton(
            key: const ValueKey<String>('timeline-retry-page'),
            onPressed: () => unawaited(onLoadMore()),
            child: const Text(AppStrings.retry),
          ),
        ],
      );
    }
    if (!state.hasMore) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        key: const ValueKey<String>('timeline-load-more'),
        onPressed: () => unawaited(onLoadMore()),
        child: const Text(AppStrings.timelineLoadMore),
      ),
    );
  }
}

final class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading({required this.responsive});

  final ResponsiveClass responsive;

  @override
  Widget build(BuildContext context) {
    if (responsive == ResponsiveClass.compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = (constraints.maxHeight - timelineDeckNextPeek - 16)
              .clamp(0.0, constraints.maxHeight);
          return SizedBox(
            key: const ValueKey<String>('timeline-compact-deck'),
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 8,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  height: cardHeight,
                  child: _TimelineLoadingCard(
                    key: const ValueKey<String>('timeline-loading-card'),
                    compact: true,
                    height: cardHeight,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    if (responsive == ResponsiveClass.medium) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.feed),
            child: const SizedBox(
              key: ValueKey<String>('timeline-medium-feed'),
              width: double.infinity,
              child: Align(
                alignment: Alignment.topCenter,
                child: _TimelineLoadingCard(),
              ),
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = _timelineSidebarWidth(constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: AppLayout.feed + AppSpacing.xl + sidebarWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(
                    key: ValueKey<String>('timeline-wide-feed'),
                    width: AppLayout.feed,
                    child: _TimelineLoadingCard(),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  SizedBox(
                    key: const ValueKey<String>('timeline-friends-sidebar'),
                    width: sidebarWidth,
                    child: const _TimelineLoadingCard(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _TimelineLoadingCard extends StatelessWidget {
  const _TimelineLoadingCard({super.key, this.compact = false, this.height});

  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) => EditorialCard.flat(
    height: height,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              SkeletonBox(width: 40, height: 40),
              SizedBox(width: AppSpacing.sm),
              SkeletonBox(width: 160, height: 18),
            ],
          ),
        ),
        if (compact)
          const Expanded(
            child: SkeletonBox(width: double.infinity, height: double.infinity),
          )
        else
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonBox(width: double.infinity, height: double.infinity),
          ),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkeletonBox(width: 200, height: 24),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 280, height: 16),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _CheckInAction extends StatelessWidget {
  const _CheckInAction();

  @override
  Widget build(BuildContext context) => OpenContainer(
    transitionType: ContainerTransitionType.fade,
    openBuilder: (_, _) => const CheckInScreen(),
    closedElevation: 0,
    closedColor: Colors.transparent,
    openColor: Theme.of(context).scaffoldBackgroundColor,
    middleColor: Theme.of(context).scaffoldBackgroundColor,
    closedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    closedBuilder: (_, open) => BounceButton(
      onTap: open,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppLayout.touchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.add_a_photo_outlined, color: Colors.white),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Check-in',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openCheckIn(BuildContext context) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const CheckInScreen()));
}

double _timelineSidebarWidth(double width) => width >= 1280 ? 304 : 280;
