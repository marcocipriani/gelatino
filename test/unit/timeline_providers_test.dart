import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/timeline_repository.dart';

final _activeUidProvider = NotifierProvider<_ActiveUidNotifier, String?>(
  _ActiveUidNotifier.new,
);
final _friendsStateProvider =
    NotifierProvider<_FriendsStateNotifier, AsyncValue<List<String>>>(
      _FriendsStateNotifier.new,
    );

void main() {
  test(
    'projection waiter retries until the published check-in is readable',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository, immediateProjectionDelay: true);
      addTearDown(container.dispose);
      final checkInId = _checkInId(7);

      final waiting = container.read(timelineProjectionWaiterProvider)(
        'alice',
        checkInId,
      );
      await _flush();
      repository.completeFirst(
        'alice',
        _page(const <FeedItem>[], token: null, hasMore: false),
      );
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[_item(7, author: 'alice')], token: null),
      );
      await waiting;

      expect(repository.firstCalls, <String>['alice', 'alice']);
    },
  );

  test(
    'authorization update before first microtask still starts initial load',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      await _flush();

      expect(repository.firstCalls, <String>['alice']);
      repository.completeFirst(
        'alice',
        _page(const <FeedItem>[], token: null, hasMore: false),
      );
      await _flush();
      final state = container.read(timelineProvider);
      expect(state.isInitialLoading, isFalse);
      expect(state.emptyState, TimelineEmptyState.noAcceptedFriends);
    },
  );

  test(
    'loads first page, single-flights next page, deduplicates and sorts',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await _flush();
      expect(repository.firstCalls, ['alice']);
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[
          _item(1, author: 'alice', minute: 1),
          _item(2, author: 'bob', minute: 2),
        ], token: 'page-1'),
      );
      await _flush();

      var state = container.read(timelineProvider);
      expect(state.items.map((item) => item.checkInId), [
        _checkInId(2),
        _checkInId(1),
      ]);
      expect(state.isInitialLoading, isFalse);
      expect(state.hasMore, isTrue);

      final controller = container.read(timelineProvider.notifier);
      final firstNext = controller.loadNextPage();
      final duplicateNext = controller.loadNextPage();
      await _flush();
      expect(repository.nextCalls, hasLength(1));
      expect(identical(firstNext, duplicateNext), isTrue);
      repository.completeNext(
        _page(
          <FeedItem>[
            _item(2, author: 'bob', minute: 2),
            _item(3, author: 'alice', minute: 3),
          ],
          token: 'page-2',
          hasMore: false,
        ),
      );
      await Future.wait(<Future<void>>[firstNext, duplicateNext]);

      state = container.read(timelineProvider);
      expect(state.items.map((item) => item.checkInId), [
        _checkInId(3),
        _checkInId(2),
        _checkInId(1),
      ]);
      expect(state.cursor?.token, 'page-2');
      expect(state.hasMore, isFalse);
      await controller.loadNextPage();
      expect(repository.nextCalls, hasLength(1));
    },
  );

  test(
    'preserves page state on retryable error and retries the same cursor',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[_item(1, author: 'alice')], token: 'page-1'),
      );
      await _flush();

      final firstAttempt = container
          .read(timelineProvider.notifier)
          .loadNextPage();
      await _flush();
      repository.failNext(const TimelineUnavailableFailure());
      await firstAttempt;

      var state = container.read(timelineProvider);
      expect(state.items.map((item) => item.checkInId), [_checkInId(1)]);
      expect(state.cursor?.token, 'page-1');
      expect(state.failure, isA<TimelineUnavailableFailure>());

      final retry = container.read(timelineProvider.notifier).loadNextPage();
      await _flush();
      expect(repository.nextCalls.map((call) => call.$2.token), [
        'page-1',
        'page-1',
      ]);
      repository.completeNext(
        _page(const <FeedItem>[], token: 'raw-malformed', hasMore: true),
      );
      await retry;

      state = container.read(timelineProvider);
      expect(state.items, hasLength(1));
      expect(state.cursor?.token, 'raw-malformed');
      expect(state.hasMore, isTrue);
      expect(state.failure, isNull);
    },
  );

  test(
    'UID switch and sign-out discard late responses and clear immediately',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();

      container.read(_activeUidProvider.notifier).set('carol');
      await _flush();
      expect(container.read(timelineProvider).items, isEmpty);
      expect(repository.firstCalls, ['alice', 'carol']);
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[_item(1, author: 'alice')], token: 'alice-page'),
      );
      await _flush();
      expect(container.read(timelineProvider).items, isEmpty);

      container.read(_activeUidProvider.notifier).set(null);
      expect(
        container.read(timelineProvider).authorizationStatus,
        TimelineAuthorizationStatus.signedOut,
      );
      expect(container.read(timelineProvider).items, isEmpty);
      repository.completeFirst(
        'carol',
        _page(<FeedItem>[_item(2, author: 'carol')], token: 'carol-page'),
      );
      await _flush();
      expect(container.read(timelineProvider).items, isEmpty);
    },
  );

  test(
    'friendship pending, failure and revocation fail closed synchronously',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[
          _item(1, author: 'alice'),
          _item(2, author: 'bob'),
        ], token: 'page-1'),
      );
      await _flush();
      expect(container.read(timelineProvider).items, hasLength(2));

      container.read(_friendsStateProvider.notifier).set(const AsyncLoading());
      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice'],
      );
      expect(
        container.read(timelineProvider).authorizationStatus,
        TimelineAuthorizationStatus.pending,
      );

      container
          .read(_friendsStateProvider.notifier)
          .set(
            AsyncError<List<String>>(
              StateError('friend stream failed'),
              StackTrace.current,
            ),
          );
      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice'],
      );
      expect(
        container.read(timelineProvider).authorizationStatus,
        TimelineAuthorizationStatus.failed,
      );

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob']));
      expect(container.read(timelineProvider).items, isEmpty);
      expect(container.read(timelineProvider).isInitialLoading, isTrue);

      await _flush();
      expect(container.read(timelineProvider).items, isEmpty);
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[
          _item(1, author: 'alice'),
          _item(2, author: 'bob'),
        ], token: 'page-2'),
      );
      await _flush();
      expect(container.read(timelineProvider).items, hasLength(2));
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice'],
      );
    },
  );

  test(
    'newly accepted friend triggers a fresh read before becoming visible',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      container.read(_friendsStateProvider.notifier).set(const AsyncLoading());
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[
          _item(1, author: 'alice'),
          _item(2, author: 'bob'),
        ], token: 'pending-page'),
      );
      await _flush();
      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice'],
      );

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob']));
      await _flush();

      expect(repository.firstCalls, ['alice', 'alice']);
      expect(container.read(timelineProvider).items, isEmpty);
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[
          _item(1, author: 'alice'),
          _item(2, author: 'bob'),
        ], token: 'authorized-page'),
      );
      await _flush();
      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice', 'bob'],
      );
    },
  );

  test(
    'authorization expansion invalidates a pending next page before fresh read',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      final emittedAuthors = <List<String>>[];
      final subscription = container.listen(timelineProvider, (_, next) {
        emittedAuthors.add(
          next.items.map((item) => item.authorUid).toList(growable: false),
        );
      }, fireImmediately: true);
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[_item(1, author: 'alice')], token: 'page-1'),
      );
      await _flush();

      final staleNext = container
          .read(timelineProvider.notifier)
          .loadNextPage();
      await _flush();
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob']));
      final synchronouslyInvalidated = container.read(timelineProvider);
      expect(synchronouslyInvalidated.items, isEmpty);
      expect(synchronouslyInvalidated.cursor, isNull);
      expect(synchronouslyInvalidated.isInitialLoading, isTrue);
      expect(synchronouslyInvalidated.isLoadingMore, isFalse);

      repository.completeNext(
        _page(<FeedItem>[_item(2, author: 'bob')], token: 'stale-page'),
      );
      await staleNext;
      await _flush();

      expect(
        emittedAuthors.where((authors) => authors.contains('bob')),
        isEmpty,
      );
      expect(repository.firstCalls, <String>['alice', 'alice']);
      final pendingFreshState = container.read(timelineProvider);
      expect(pendingFreshState.items, isEmpty);
      expect(pendingFreshState.cursor, isNull);
      expect(pendingFreshState.isInitialLoading, isTrue);

      repository.completeFirst(
        'alice',
        _page(
          <FeedItem>[_item(3, author: 'bob')],
          token: 'fresh-page',
          hasMore: false,
        ),
      );
      await _flush();
      expect(
        container.read(timelineProvider).items.single.checkInId,
        _checkInId(3),
      );
    },
  );

  test(
    'filters newly completed pages against the latest accepted friend set',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(<FeedItem>[_item(1, author: 'alice')], token: 'page-1'),
      );
      await _flush();

      final loading = container.read(timelineProvider.notifier).loadNextPage();
      await _flush();
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      repository.completeNext(
        _page(<FeedItem>[_item(2, author: 'bob')], token: 'page-2'),
      );
      await loading;

      expect(
        container.read(timelineProvider).items.map((item) => item.authorUid),
        ['alice'],
      );
      expect(container.read(timelineProvider).cursor?.token, 'page-2');
    },
  );

  test(
    'differentiates no friends from accepted friends without activity',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(const <FeedItem>[], token: null, hasMore: false),
      );
      await _flush();
      expect(
        container.read(timelineProvider).emptyState,
        TimelineEmptyState.friendsWithoutActivity,
      );

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      expect(
        container.read(timelineProvider).emptyState,
        TimelineEmptyState.noAcceptedFriends,
      );
    },
  );

  test(
    'friends activity returns every accepted profile with nullable latest item',
    () async {
      final repository = _QueuedTimelineRepository();
      final profiles = <PublicProfile>[_profile('bob'), _profile('carol')];
      final container = _container(
        repository,
        acceptedProfiles: AsyncData(profiles),
      );
      addTearDown(container.dispose);
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob', 'carol']));
      final subscription = container.listen(
        timelineProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      repository.completeFirst(
        'alice',
        _page(
          <FeedItem>[
            _item(1, author: 'bob', minute: 1),
            _item(2, author: 'bob', minute: 3),
            _item(3, author: 'alice', minute: 4),
          ],
          token: 'page-1',
          hasMore: false,
        ),
      );
      await _flush();

      final activities = container.read(friendsActivityProvider).requireValue;
      expect(activities.map((activity) => activity.profile.uid), [
        'bob',
        'carol',
      ]);
      expect(activities[0].latestItem?.checkInId, _checkInId(2));
      expect(activities[1].latestItem, isNull);
    },
  );

  test('friends activity exposes authorization loading and failure', () {
    final repository = _QueuedTimelineRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    container.read(_friendsStateProvider.notifier).set(const AsyncLoading());
    expect(container.read(friendsActivityProvider).isLoading, isTrue);

    final error = StateError('friend authorization failed');
    container
        .read(_friendsStateProvider.notifier)
        .set(AsyncError<List<String>>(error, StackTrace.current));
    expect(container.read(friendsActivityProvider).error, same(error));
  });

  test(
    'authorized history fails closed until the requested friend is accepted',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      container.read(_friendsStateProvider.notifier).set(const AsyncLoading());

      expect(
        container.read(authorizedHistoryProvider('bob')).isLoading,
        isTrue,
      );
      expect(repository.historyCalls, isEmpty);

      container
          .read(_friendsStateProvider.notifier)
          .set(
            AsyncError<List<String>>(
              StateError('friend stream failed'),
              StackTrace.current,
            ),
          );
      final failed = container.read(authorizedHistoryProvider('bob'));
      expect(failed.hasError, isTrue);
      expect(repository.historyCalls, isEmpty);

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      final denied = container.read(authorizedHistoryProvider('bob'));
      expect(denied.error, isA<TimelinePermissionFailure>());
      expect(repository.historyCalls, isEmpty);

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob']));
      final subscription = container.listen(
        authorizedHistoryProvider('bob'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      expect(repository.historyCalls, hasLength(1));
      expect(repository.historyCalls.single.$1, 'alice');
      expect(repository.historyCalls.single.$2, 'bob');
      repository.completeHistory(
        _page(<FeedItem>[_item(2, author: 'bob')], token: 'history'),
      );
      await _flush();
      expect(
        container
            .read(authorizedHistoryProvider('bob'))
            .requireValue
            .single
            .authorUid,
        'bob',
      );
    },
  );

  test(
    'authorized history creates a new read after revocation and reacceptance',
    () async {
      final repository = _QueuedTimelineRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final subscription = container.listen(
        authorizedHistoryProvider('bob'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await _flush();
      expect(repository.historyCalls, hasLength(1));
      repository.completeHistory(
        _page(<FeedItem>[_item(1, author: 'bob')], token: 'first-history'),
      );
      await _flush();
      expect(
        container
            .read(authorizedHistoryProvider('bob'))
            .requireValue
            .single
            .checkInId,
        _checkInId(1),
      );

      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>[]));
      expect(
        container.read(authorizedHistoryProvider('bob')).error,
        isA<TimelinePermissionFailure>(),
      );
      container
          .read(_friendsStateProvider.notifier)
          .set(const AsyncData(<String>['bob']));
      expect(
        container.read(authorizedHistoryProvider('bob')).isLoading,
        isTrue,
      );
      await _flush();
      expect(repository.historyCalls, hasLength(2));

      repository.completeHistory(
        _page(<FeedItem>[_item(2, author: 'bob')], token: 'second-history'),
      );
      await _flush();
      expect(
        container
            .read(authorizedHistoryProvider('bob'))
            .requireValue
            .single
            .checkInId,
        _checkInId(2),
      );
    },
  );
}

ProviderContainer _container(
  TimelineRepository repository, {
  AsyncValue<List<PublicProfile>>? acceptedProfiles,
  bool immediateProjectionDelay = false,
}) => ProviderContainer(
  overrides: [
    currentUidProvider.overrideWith((ref) => ref.watch(_activeUidProvider)),
    acceptedFriendsProvider.overrideWith(
      (ref) => ref.watch(_friendsStateProvider),
    ),
    timelineRepositoryProvider.overrideWithValue(repository),
    if (immediateProjectionDelay)
      timelineProjectionDelayProvider.overrideWithValue((_) async {}),
    if (acceptedProfiles != null)
      acceptedFriendProfilesProvider.overrideWithValue(acceptedProfiles),
  ],
);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _ActiveUidNotifier extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final class _FriendsStateNotifier extends Notifier<AsyncValue<List<String>>> {
  @override
  AsyncValue<List<String>> build() => const AsyncData(<String>['bob']);

  void set(AsyncValue<List<String>> value) => state = value;
}

final class _QueuedTimelineRepository implements TimelineRepository {
  final List<String> firstCalls = <String>[];
  final List<(String, FeedCursor)> nextCalls = <(String, FeedCursor)>[];
  final List<(String, String, Set<String>)> historyCalls =
      <(String, String, Set<String>)>[];
  final Map<String, List<Completer<FeedPage>>> _first =
      <String, List<Completer<FeedPage>>>{};
  final List<Completer<FeedPage>> _next = <Completer<FeedPage>>[];
  final List<Completer<FeedPage>> _history = <Completer<FeedPage>>[];

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) {
    firstCalls.add(uid);
    final completer = Completer<FeedPage>();
    (_first[uid] ??= <Completer<FeedPage>>[]).add(completer);
    return completer.future;
  }

  @override
  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20}) {
    nextCalls.add((uid, cursor));
    final completer = Completer<FeedPage>();
    _next.add(completer);
    return completer.future;
  }

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) {
    historyCalls.add((
      ownerUid,
      authorUid,
      Set<String>.of(authorizedAuthorUids),
    ));
    final completer = Completer<FeedPage>();
    _history.add(completer);
    return completer.future;
  }

  void completeFirst(String uid, FeedPage page) {
    _first[uid]!.removeAt(0).complete(page);
  }

  void completeNext(FeedPage page) => _next.removeAt(0).complete(page);

  void failNext(TimelineFailure failure) =>
      _next.removeAt(0).completeError(failure);

  void completeHistory(FeedPage page) => _history.removeAt(0).complete(page);
}

FeedPage _page(
  List<FeedItem> items, {
  required Object? token,
  bool hasMore = true,
}) => FeedPage(
  items: items,
  cursor: token == null ? null : FeedCursor(ownerUid: 'alice', token: token),
  hasMore: hasMore,
);

FeedItem _item(int suffix, {required String author, int minute = 0}) {
  final id = _checkInId(suffix);
  return FeedItem.fromMap(<String, dynamic>{
    'author_uid': author,
    'check_in_id': id,
    'user_snapshot': <String, dynamic>{
      'display_name': author,
      'username': author,
      'avatar_path': null,
    },
    'place_id': 'place-1',
    'place_snapshot': <String, dynamic>{'name': 'Giolitti', 'address': 'Roma'},
    'gelato_type': <String, dynamic>{'id': 'cup', 'name': 'Coppetta'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistachio', 'name': 'Pistacchio'},
    ],
    'rating': 5,
    'review_text': 'Ottimo',
    'tagged_user_ids': const <String>[],
    'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15, 12, minute)),
    'photo_storage_path': 'check_ins/$author/$id/photo.jpg',
  }, id);
}

PublicProfile _profile(String uid) => PublicProfile.fromMap(<String, dynamic>{
  'uid': uid,
  'display_name': uid,
  'display_name_lower': uid,
  'username': uid,
  'username_lower': uid,
  'avatar_path': null,
  'bio': '',
  'city': 'Roma',
  'favorite_place_id': null,
  'favorite_flavor_id': null,
  'favorite_flavor_ids': const <String>[],
  'profile_visibility': 'friends',
  'searchable': false,
  'points': 0,
  'updated_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
}, uid);

String _checkInId(int suffix) =>
    'checkin_1234567890${suffix.toString().padLeft(2, '0')}';
