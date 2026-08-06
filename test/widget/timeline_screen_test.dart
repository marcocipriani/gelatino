import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/timeline_repository.dart';
import 'package:gelatino/screens/timeline_screen.dart';

void main() {
  test('timeline screen binds only the paginated private feed controller', () {
    final source = File('lib/screens/timeline_screen.dart').readAsStringSync();

    expect(source, contains('timelineProvider'));
    expect(source, contains('loadNextPage'));
    expect(source, contains('TimelineEmptyState.noAcceptedFriends'));
    expect(source, contains('TimelineEmptyState.friendsWithoutActivity'));
    expect(source, isNot(contains('checkInsProvider')));
    expect(source, isNot(contains('check_ins_provider.dart')));
    expect(source, isNot(contains('CachedNetworkImage')));
  });

  test(
    'profile labels bounded history honestly and never imports global check-ins',
    () {
      final source = File('lib/screens/profile_screen.dart').readAsStringSync();

      expect(source, contains('authorizedHistoryProvider'));
      // Display strings live in AppStrings; assert the labels are referenced.
      expect(AppStrings.profileRecentActivity, 'Attività recenti');
      expect(AppStrings.profileCheckInsPageLabel, contains('Check-in caricati'));
      expect(source, contains('AppStrings.profileRecentActivity'));
      expect(source, contains('AppStrings.profileCheckInsPageLabel'));
      expect(source, isNot(contains('checkInsProvider')));
      expect(source, isNot(contains('models/check_in.dart')));
      expect(source, isNot(contains('gelato_type_stats.dart')));
    },
  );

  test('raw history page provider stays private to the authorization gate', () {
    final source = File(
      'lib/providers/timeline_providers.dart',
    ).readAsStringSync();

    expect(source, contains('_timelineHistoryPageProvider'));
    expect(source, isNot(contains('final timelineHistoryPageProvider')));
  });

  testWidgets(
    'empty copy distinguishes no friends from friends without activity',
    (tester) async {
      await _pumpTimeline(
        tester,
        repository: _TimelineRepository(page: _emptyPage),
        acceptedFriends: const <String>[],
      );
      expect(find.text('Nessun amico ancora'), findsOneWidget);

      await _pumpTimeline(
        tester,
        repository: _TimelineRepository(page: _emptyPage),
        acceptedFriends: const <String>['bob'],
      );
      expect(find.text('Nessun check-in recente'), findsOneWidget);
    },
  );

  testWidgets('initial page failure is visible and retryable', (tester) async {
    await _pumpTimeline(
      tester,
      repository: _TimelineRepository(
        error: const TimelineUnavailableFailure(),
      ),
      acceptedFriends: const <String>[],
    );

    expect(
      find.text('Timeline temporaneamente non disponibile. Riprova.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-retry')),
      findsOneWidget,
    );
  });
}

final _emptyPage = FeedPage(items: const [], cursor: null, hasMore: false);

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required _TimelineRepository repository,
  required List<String> acceptedFriends,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        acceptedFriendsProvider.overrideWithValue(AsyncData(acceptedFriends)),
        timelineRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: TimelineScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

final class _TimelineRepository implements TimelineRepository {
  _TimelineRepository({this.page, this.error});

  final FeedPage? page;
  final TimelineFailure? error;

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) async {
    if (error case final failure?) throw failure;
    return page!;
  }

  @override
  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20}) =>
      firstPage(uid, limit: limit);

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) => firstPage(ownerUid, limit: limit);
}
