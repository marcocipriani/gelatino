import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/leaderboard_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';

void main() {
  group('currentMonthKey', () {
    test('matches functions UTC format', () {
      expect(currentMonthKey(DateTime.utc(2026, 7, 17)), '2026-07');
      // istante locale che cade nel mese UTC precedente
      expect(
        currentMonthKey(DateTime.parse('2026-08-01T01:00:00+02:00')),
        '2026-07',
      );
    });
  });

  group('rankLeaderboard', () {
    test('sorts desc and treats missing month as zero', () {
      final entries = rankLeaderboard(
        period: LeaderboardPeriod.month,
        monthKey: '2026-07',
        profiles: [
          // (uid, points all-time, monthly)
          fakeProfile('a', points: 900, monthly: {}),
          fakeProfile('b', points: 10, monthly: {'2026-07': 40}),
          fakeProfile('c', points: 500, monthly: {'2026-07': 5}),
        ],
        currentUid: 'c',
      );
      expect(entries.map((e) => e.uid).toList(), ['b', 'c', 'a']);
      expect(entries.firstWhere((e) => e.uid == 'c').isCurrentUser, isTrue);
    });

    test('allTime period uses all-time points, ignoring monthlyPoints', () {
      final entries = rankLeaderboard(
        period: LeaderboardPeriod.allTime,
        monthKey: '2026-07',
        profiles: [
          fakeProfile('a', points: 900, monthly: {'2026-07': 5}),
          fakeProfile('b', points: 10, monthly: {'2026-07': 400}),
        ],
        currentUid: null,
      );
      expect(entries.map((e) => e.uid).toList(), ['a', 'b']);
      expect(entries.map((e) => e.points).toList(), [900, 10]);
    });

    test('ties break by display name, case-insensitive', () {
      final entries = rankLeaderboard(
        period: LeaderboardPeriod.allTime,
        monthKey: '2026-07',
        profiles: [
          fakeProfile('a', points: 10, displayName: 'zeta'),
          fakeProfile('b', points: 10, displayName: 'Alpha'),
        ],
        currentUid: null,
      );
      expect(entries.map((e) => e.uid).toList(), ['b', 'a']);
    });

    test('no current uid means no entry is flagged', () {
      final entries = rankLeaderboard(
        period: LeaderboardPeriod.allTime,
        monthKey: '2026-07',
        profiles: [fakeProfile('a', points: 10)],
        currentUid: null,
      );
      expect(entries.single.isCurrentUser, isFalse);
    });
  });

  group('leaderboardProvider', () {
    test('combines accepted friends with own profile and ranks by month', () async {
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          acceptedFriendProfilesProvider.overrideWithValue(
            AsyncData<List<PublicProfile>>([
              _publicProfile(
                'bob',
                'Bob',
                points: 900,
                monthlyPoints: const {},
              ),
              _publicProfile(
                'carol',
                'Carol',
                points: 5,
                monthlyPoints: {_thisMonthKey: 40},
              ),
            ]),
          ),
          ownProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(
              UserProfile(
                uid: 'alice',
                displayName: 'Alice',
                points: 500,
                monthlyPoints: {_thisMonthKey: 5},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        leaderboardProvider(LeaderboardPeriod.month),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.pump();

      final monthResult = container.read(
        leaderboardProvider(LeaderboardPeriod.month),
      );
      expect(
        monthResult.value?.map((e) => e.uid).toList(),
        ['carol', 'alice', 'bob'],
      );
      expect(
        monthResult.value?.firstWhere((e) => e.uid == 'alice').isCurrentUser,
        isTrue,
      );

      final allTimeResult = container.read(
        leaderboardProvider(LeaderboardPeriod.allTime),
      );
      expect(
        allTimeResult.value?.map((e) => e.uid).toList(),
        ['bob', 'alice', 'carol'],
      );
    });

    test('missing monthly_points on real profiles counts as zero', () async {
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          acceptedFriendProfilesProvider.overrideWithValue(
            AsyncData<List<PublicProfile>>([
              _publicProfile('bob', 'Bob', points: 200),
            ]),
          ),
          ownProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(
              UserProfile(uid: 'alice', displayName: 'Alice', points: 5),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        leaderboardProvider(LeaderboardPeriod.month),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.pump();

      final result = container.read(
        leaderboardProvider(LeaderboardPeriod.month),
      );
      expect(result.value?.map((e) => e.points).toList(), [0, 0]);
    });

    test('propagates friends error', () async {
      final error = StateError('friends unavailable');
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          acceptedFriendProfilesProvider.overrideWithValue(
            AsyncError<List<PublicProfile>>(error, StackTrace.empty),
          ),
          ownProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(
              UserProfile(uid: 'alice', displayName: 'Alice'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        leaderboardProvider(LeaderboardPeriod.allTime),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.pump();

      final result = container.read(
        leaderboardProvider(LeaderboardPeriod.allTime),
      );
      expect(result.hasError, isTrue);
      expect(result.error, error);
    });

    test('loading friends yields loading leaderboard', () {
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          acceptedFriendProfilesProvider.overrideWithValue(
            const AsyncLoading<List<PublicProfile>>(),
          ),
          ownProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(
              UserProfile(uid: 'alice', displayName: 'Alice'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(
        leaderboardProvider(LeaderboardPeriod.allTime),
      );
      expect(result.isLoading, isTrue);
    });
  });
}

String get _thisMonthKey => currentMonthKey(DateTime.now());

LeaderboardInput fakeProfile(
  String uid, {
  required int points,
  Map<String, int> monthly = const <String, int>{},
  String? displayName,
}) {
  return LeaderboardInput(
    uid: uid,
    displayName: displayName ?? uid,
    avatarPath: null,
    points: points,
    monthlyPoints: monthly,
  );
}

PublicProfile _publicProfile(
  String uid,
  String displayName, {
  required int points,
  Map<String, int> monthlyPoints = const <String, int>{},
}) => PublicProfile.fromMap(<String, dynamic>{
  'uid': uid,
  'display_name': displayName,
  'display_name_lower': displayName.toLowerCase(),
  'username': uid,
  'username_lower': uid,
  'avatar_path': null,
  'bio': '',
  'city': 'Roma',
  'favorite_place_id': null,
  'favorite_flavor_id': null,
  'favorite_flavor_ids': <String>[],
  'profile_visibility': 'public',
  'searchable': true,
  'points': points,
  'monthly_points': monthlyPoints,
  'updated_at': Timestamp.fromDate(DateTime(2026, 7, 14)),
}, uid);
