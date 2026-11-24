import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../providers/leaderboard_provider.dart';
import '../../screens/friends/friends_sections.dart';
import '../app_controls.dart';
import '../avatar_image_provider.dart';
import '../../constants/app_strings.dart';

/// First section of the Amici tab: taste-points leaderboard among the
/// current user and their accepted friends, toggled between this month and
/// all-time.
final class LeaderboardSection extends ConsumerStatefulWidget {
  const LeaderboardSection({super.key});

  @override
  ConsumerState<LeaderboardSection> createState() =>
      _LeaderboardSectionState();
}

class _LeaderboardSectionState extends ConsumerState<LeaderboardSection> {
  LeaderboardPeriod _period = LeaderboardPeriod.month;

  void _setPeriod(LeaderboardPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
  }

  @override
  Widget build(BuildContext context) {
    final leaderboard = ref.watch(leaderboardProvider(_period));
    return FriendsSection(
      title: AppStrings.leaderboardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodToggle(period: _period, onChanged: _setPeriod),
          const SizedBox(height: AppSpacing.md),
          leaderboard.when(
            data: (entries) => entries.length <= 1
                ? const _LeaderboardEmpty()
                : _LeaderboardRanking(entries: entries),
            loading: () => const FriendsSkeleton(rows: 2),
            error: (error, stackTrace) => FriendsStatePanel(
              title: AppStrings.leaderboardUnavailable,
              message: AppStrings.leaderboardLoadError,
              actionLabel: AppStrings.retry,
              onAction: () => ref.invalidate(leaderboardProvider(_period)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSegmented<LeaderboardPeriod>(
      key: const ValueKey('leaderboard-period-toggle'),
      value: period,
      onChanged: onChanged,
      segments: {
        LeaderboardPeriod.month: AppStrings.leaderboardPeriodMonth,
        LeaderboardPeriod.allTime: AppStrings.leaderboardPeriodAll,
      },
    );
  }
}

class _LeaderboardEmpty extends StatelessWidget {
  const _LeaderboardEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.icecream_outlined, color: theme.colorScheme.accentInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.leaderboardEmptyDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRanking extends StatelessWidget {
  const _LeaderboardRanking({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final podium = entries.take(3).toList(growable: false);
    final rest = entries.skip(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Podium(entries: podium),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final (index, entry) in rest.indexed)
            _LeaderboardRow(rank: index + 4, entry: entry),
        ],
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, entry) in entries.indexed)
          Expanded(
            key: ValueKey('leaderboard-podium-${entry.uid}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AuthenticatedAvatar(source: entry.avatarPath, radius: 32),
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: index == 0
                              ? AppColors.sorbetto
                              : theme.colorScheme.inverseSurface,
                          child: Text(
                            '${index + 1}',
                            semanticsLabel: '${index + 1}º posto',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: index == 0
                                  ? AppColors.fondente
                                  : theme.colorScheme.onInverseSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entry.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: entry.isCurrentUser
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppStrings.leaderboardPoints(entry.points),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('leaderboard-row-${entry.uid}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? theme.colorScheme.primaryContainer
            : null,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.lg,
            child: Text('$rank', style: theme.textTheme.bodyMedium),
          ),
          AuthenticatedAvatar(source: entry.avatarPath, radius: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: entry.isCurrentUser
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            AppStrings.leaderboardPoints(entry.points),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
