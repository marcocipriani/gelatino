import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_profile.dart';
import 'auth_provider.dart';
import 'friendship_providers.dart';
import 'profile_providers.dart';

enum LeaderboardPeriod { month, allTime }

String currentMonthKey(DateTime now) {
  final utc = now.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}';
}

class LeaderboardInput {
  const LeaderboardInput({
    required this.uid,
    required this.displayName,
    required this.avatarPath,
    required this.points,
    required this.monthlyPoints,
  });

  final String uid;
  final String displayName;
  final String? avatarPath;
  final int points;
  final Map<String, int> monthlyPoints;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatarPath,
    required this.points,
    required this.isCurrentUser,
  });

  final String uid;
  final String displayName;
  final String? avatarPath;
  final int points;
  final bool isCurrentUser;
}

List<LeaderboardEntry> rankLeaderboard({
  required LeaderboardPeriod period,
  required String monthKey,
  required List<LeaderboardInput> profiles,
  required String? currentUid,
}) {
  final entries = profiles
      .map(
        (p) => LeaderboardEntry(
          uid: p.uid,
          displayName: p.displayName,
          avatarPath: p.avatarPath,
          points: period == LeaderboardPeriod.allTime
              ? p.points
              : p.monthlyPoints[monthKey] ?? 0,
          isCurrentUser: p.uid == currentUid,
        ),
      )
      .toList();
  entries.sort((a, b) {
    final byPoints = b.points.compareTo(a.points);
    return byPoints != 0
        ? byPoints
        : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return List<LeaderboardEntry>.unmodifiable(entries);
}

final leaderboardProvider = Provider.autoDispose
    .family<AsyncValue<List<LeaderboardEntry>>, LeaderboardPeriod>((
      ref,
      period,
    ) {
      final friends = ref.watch(acceptedFriendProfilesProvider);
      final own = ref.watch(ownProfileProvider);
      final uid = ref.watch(currentUidProvider);
      if (friends.isLoading || own.isLoading) return const AsyncLoading();
      if (friends.hasError) {
        return AsyncError(friends.error!, friends.stackTrace!);
      }
      // ponytail: own-profile errors degrade softly (leaderboard renders
      // without the current user) — signed off 2026-07-19; friends errors
      // stay hard because without them there is no leaderboard at all.
      final inputs = <LeaderboardInput>[
        for (final p in friends.value ?? const <PublicProfile>[])
          LeaderboardInput(
            uid: p.uid,
            displayName: p.displayName,
            avatarPath: p.avatarPath,
            points: p.points,
            monthlyPoints: p.monthlyPoints,
          ),
        if (own.value case final me?)
          LeaderboardInput(
            uid: me.uid,
            displayName: me.displayName,
            avatarPath: me.avatarPath,
            points: me.points,
            monthlyPoints: me.monthlyPoints,
          ),
      ];
      return AsyncData(
        rankLeaderboard(
          period: period,
          monthKey: currentMonthKey(DateTime.now()),
          profiles: inputs,
          currentUid: uid,
        ),
      );
    });
