import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/feed_item.dart';
import '../models/public_profile.dart';
import '../repositories/timeline_repository.dart';
import 'auth_provider.dart';
import 'friendship_providers.dart';

final timelineDataSourceProvider = Provider<TimelineDataSource>((ref) {
  return FirestoreTimelineDataSource(ref.watch(firestoreProvider));
});

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepositoryImpl(ref.watch(timelineDataSourceProvider));
});

typedef TimelineProjectionWaiter =
    Future<void> Function(String uid, String checkInId);
typedef TimelineProjectionDelay = Future<void> Function(Duration duration);

final timelineProjectionDelayProvider = Provider<TimelineProjectionDelay>(
  (ref) => Future<void>.delayed,
);

final timelineProjectionWaiterProvider = Provider<TimelineProjectionWaiter>((
  ref,
) {
  final repository = ref.watch(timelineRepositoryProvider);
  final delay = ref.watch(timelineProjectionDelayProvider);
  return (uid, checkInId) async {
    const attempts = 8;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final page = await repository.firstPage(uid);
        if (page.items.any((item) => item.checkInId == checkInId)) return;
      } on Object {
        // Publication is complete even if projection readiness cannot be read.
      }
      if (attempt + 1 == attempts) return;
      await delay(Duration(milliseconds: 250 * (attempt + 1)));
    }
  };
});

enum TimelineAuthorizationStatus { signedOut, pending, authorized, failed }

enum TimelineEmptyState {
  none,
  signedOut,
  authorizationPending,
  authorizationFailed,
  noAcceptedFriends,
  friendsWithoutActivity,
}

final class TimelineState {
  TimelineState({
    List<FeedItem> items = const <FeedItem>[],
    required this.cursor,
    required this.hasMore,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.acceptedFriendCount,
    required this.authorizationStatus,
    required this.failure,
  }) : items = List<FeedItem>.unmodifiable(items);

  final List<FeedItem> items;
  final FeedCursor? cursor;
  final bool hasMore;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final int acceptedFriendCount;
  final TimelineAuthorizationStatus authorizationStatus;
  final TimelineFailure? failure;

  TimelineEmptyState get emptyState {
    if (items.isNotEmpty || isInitialLoading) return TimelineEmptyState.none;
    return switch (authorizationStatus) {
      TimelineAuthorizationStatus.signedOut => TimelineEmptyState.signedOut,
      TimelineAuthorizationStatus.pending =>
        TimelineEmptyState.authorizationPending,
      TimelineAuthorizationStatus.failed =>
        TimelineEmptyState.authorizationFailed,
      TimelineAuthorizationStatus.authorized =>
        acceptedFriendCount == 0
            ? TimelineEmptyState.noAcceptedFriends
            : TimelineEmptyState.friendsWithoutActivity,
    };
  }
}

final timelineProvider =
    NotifierProvider.autoDispose<TimelineController, TimelineState>(
      TimelineController.new,
    );

final class TimelineController extends Notifier<TimelineState> {
  String? _activeUid;
  int _generation = 0;
  List<FeedItem> _items = const <FeedItem>[];
  FeedCursor? _cursor;
  bool _hasMore = true;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  int _acceptedFriendCount = 0;
  TimelineAuthorizationStatus _authorizationStatus =
      TimelineAuthorizationStatus.signedOut;
  TimelineFailure? _failure;
  Set<String> _allowedAuthorUids = const <String>{};
  Future<void>? _nextOperation;

  @override
  TimelineState build() {
    final uid = ref.watch(currentUidProvider);
    final acceptedFriends = ref.watch(acceptedFriendsProvider);
    final identityChanged = uid != _activeUid;
    final previouslyAllowed = _allowedAuthorUids;
    if (identityChanged) {
      _activeUid = uid;
      _generation++;
      _items = const <FeedItem>[];
      _cursor = null;
      _hasMore = uid != null;
      _isInitialLoading = uid != null;
      _isLoadingMore = false;
      _failure = null;
      _nextOperation = null;
    }

    _updateAuthorization(uid, acceptedFriends);
    _items = _authorized(_items);

    final authorizationExpanded =
        !identityChanged &&
        uid != null &&
        _allowedAuthorUids
            .difference(previouslyAllowed)
            .any((authorUid) => authorUid != uid);

    if (authorizationExpanded) {
      _generation++;
      _items = const <FeedItem>[];
      _cursor = null;
      _hasMore = true;
      _isInitialLoading = true;
      _isLoadingMore = false;
      _failure = null;
      _nextOperation = null;
    }

    if ((identityChanged && uid != null) || authorizationExpanded) {
      Future<void>.microtask(() async {
        if (ref.mounted && _activeUid == uid) await refresh();
      });
    }
    return _snapshot();
  }

  Future<void> refresh() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || uid != _activeUid) return;
    final generation = ++_generation;
    _items = const <FeedItem>[];
    _cursor = null;
    _hasMore = true;
    _isInitialLoading = true;
    _isLoadingMore = false;
    _failure = null;
    _nextOperation = null;
    _emit();
    try {
      final page = await ref.read(timelineRepositoryProvider).firstPage(uid);
      if (!_isCurrent(uid, generation)) return;
      _items = _merge(const <FeedItem>[], _authorized(page.items));
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _isInitialLoading = false;
      _failure = null;
      _emit();
    } on TimelineFailure catch (failure) {
      if (!_isCurrent(uid, generation)) return;
      _isInitialLoading = false;
      _failure = failure;
      _emit();
    } catch (_) {
      if (!_isCurrent(uid, generation)) return;
      _isInitialLoading = false;
      _failure = const TimelineUnknownFailure('unknown');
      _emit();
    }
  }

  Future<void> loadNextPage() {
    final existing = _nextOperation;
    if (existing != null) return existing;
    final uid = _activeUid;
    final cursor = _cursor;
    if (uid == null || cursor == null || !_hasMore) {
      return Future<void>.value();
    }
    final generation = _generation;
    _isLoadingMore = true;
    _failure = null;
    _emit();
    late final Future<void> operation;
    operation = _loadNext(uid, cursor, generation).whenComplete(() {
      if (identical(_nextOperation, operation)) _nextOperation = null;
    });
    _nextOperation = operation;
    return operation;
  }

  Future<void> _loadNext(String uid, FeedCursor cursor, int generation) async {
    try {
      final page = await ref
          .read(timelineRepositoryProvider)
          .nextPage(uid, cursor);
      if (!_isCurrent(uid, generation)) return;
      _items = _merge(_items, _authorized(page.items));
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _isLoadingMore = false;
      _failure = null;
      _emit();
    } on TimelineFailure catch (failure) {
      if (!_isCurrent(uid, generation)) return;
      _isLoadingMore = false;
      _failure = failure;
      _emit();
    } catch (_) {
      if (!_isCurrent(uid, generation)) return;
      _isLoadingMore = false;
      _failure = const TimelineUnknownFailure('unknown');
      _emit();
    }
  }

  void _updateAuthorization(
    String? uid,
    AsyncValue<List<String>> acceptedFriends,
  ) {
    if (uid == null) {
      _authorizationStatus = TimelineAuthorizationStatus.signedOut;
      _acceptedFriendCount = 0;
      _allowedAuthorUids = const <String>{};
      return;
    }
    if (acceptedFriends.isLoading) {
      _authorizationStatus = TimelineAuthorizationStatus.pending;
      _acceptedFriendCount = 0;
      _allowedAuthorUids = <String>{uid};
      return;
    }
    if (acceptedFriends.hasError) {
      _authorizationStatus = TimelineAuthorizationStatus.failed;
      _acceptedFriendCount = 0;
      _allowedAuthorUids = <String>{uid};
      return;
    }
    final friendUids = acceptedFriends.value ?? const <String>[];
    final uniqueFriendUids = friendUids
        .where((friendUid) => friendUid != uid)
        .toSet();
    _authorizationStatus = TimelineAuthorizationStatus.authorized;
    _acceptedFriendCount = uniqueFriendUids.length;
    _allowedAuthorUids = <String>{uid, ...uniqueFriendUids};
  }

  List<FeedItem> _authorized(Iterable<FeedItem> items) =>
      List<FeedItem>.unmodifiable(
        items.where((item) => _allowedAuthorUids.contains(item.authorUid)),
      );

  List<FeedItem> _merge(
    Iterable<FeedItem> current,
    Iterable<FeedItem> incoming,
  ) {
    final byId = <String, FeedItem>{
      for (final item in current) item.checkInId: item,
    };
    for (final item in incoming) {
      byId.putIfAbsent(item.checkInId, () => item);
    }
    final ordered = byId.values.toList()
      ..sort((left, right) {
        final createdAt = right.createdAt.compareTo(left.createdAt);
        return createdAt != 0
            ? createdAt
            : left.checkInId.compareTo(right.checkInId);
      });
    return List<FeedItem>.unmodifiable(ordered);
  }

  bool _isCurrent(String uid, int generation) =>
      ref.mounted && _activeUid == uid && _generation == generation;

  void _emit() {
    if (ref.mounted) state = _snapshot();
  }

  TimelineState _snapshot() => TimelineState(
    items: _items,
    cursor: _cursor,
    hasMore: _hasMore,
    isInitialLoading: _isInitialLoading,
    isLoadingMore: _isLoadingMore,
    acceptedFriendCount: _acceptedFriendCount,
    authorizationStatus: _authorizationStatus,
    failure: _failure,
  );
}

final class FriendActivity {
  const FriendActivity({required this.profile, required this.latestItem});

  final PublicProfile profile;
  final FeedItem? latestItem;
}

final friendsActivityProvider =
    Provider.autoDispose<AsyncValue<List<FriendActivity>>>((ref) {
      final acceptedUids = ref.watch(acceptedFriendsProvider);
      if (acceptedUids.isLoading) return const AsyncLoading();
      if (acceptedUids.hasError) {
        return AsyncError<List<FriendActivity>>(
          acceptedUids.error!,
          acceptedUids.stackTrace ?? StackTrace.current,
        );
      }
      final allowed = (acceptedUids.value ?? const <String>[]).toSet();
      final profiles = ref.watch(acceptedFriendProfilesProvider);
      return profiles.whenData((values) {
        final items = ref.watch(timelineProvider).items;
        final latestByUid = <String, FeedItem>{};
        for (final item in items) {
          if (allowed.contains(item.authorUid)) {
            latestByUid.putIfAbsent(item.authorUid, () => item);
          }
        }
        return List<FriendActivity>.unmodifiable(
          values
              .where((profile) => allowed.contains(profile.uid))
              .map(
                (profile) => FriendActivity(
                  profile: profile,
                  latestItem: latestByUid[profile.uid],
                ),
              ),
        );
      });
    });

typedef TimelineHistoryKey = ({
  String ownerUid,
  String authorUid,
  Object? authorizationEpoch,
});

final _timelineHistoryAuthorizationEpochProvider = Provider.autoDispose<Object>(
  (ref) {
    ref.watch(acceptedFriendsProvider);
    return Object();
  },
);

final _timelineHistoryPageProvider = FutureProvider.autoDispose
    .family<FeedPage, TimelineHistoryKey>((ref, key) {
      return ref
          .watch(timelineRepositoryProvider)
          .authorHistory(
            key.ownerUid,
            key.authorUid,
            authorizedAuthorUids: <String>{key.ownerUid, key.authorUid},
          );
    });

final authorizedHistoryProvider = Provider.autoDispose
    .family<AsyncValue<List<FeedItem>>, String>((ref, requestedAuthorUid) {
      final ownerUid = ref.watch(currentUidProvider);
      if (ownerUid == null) return const AsyncData(<FeedItem>[]);
      if (requestedAuthorUid == ownerUid) {
        return ref
            .watch(
              _timelineHistoryPageProvider((
                ownerUid: ownerUid,
                authorUid: requestedAuthorUid,
                authorizationEpoch: null,
              )),
            )
            .whenData((page) => page.items);
      }

      final acceptedFriends = ref.watch(acceptedFriendsProvider);
      final authorizationEpoch = ref.watch(
        _timelineHistoryAuthorizationEpochProvider,
      );
      if (acceptedFriends.isLoading) return const AsyncLoading();
      if (acceptedFriends.hasError) {
        return AsyncError<List<FeedItem>>(
          acceptedFriends.error!,
          acceptedFriends.stackTrace ?? StackTrace.current,
        );
      }
      final authorized =
          acceptedFriends.value?.contains(requestedAuthorUid) ?? false;
      if (!authorized) {
        return AsyncError<List<FeedItem>>(
          const TimelinePermissionFailure(),
          StackTrace.current,
        );
      }
      return ref
          .watch(
            _timelineHistoryPageProvider((
              ownerUid: ownerUid,
              authorUid: requestedAuthorUid,
              authorizationEpoch: authorizationEpoch,
            )),
          )
          .whenData((page) => page.items);
    });

final authorizedHistoryRefreshProvider =
    Provider.family<void Function(), String>((ref, requestedAuthorUid) {
      return () {
        final ownerUid = ref.read(currentUidProvider);
        if (ownerUid == null) return;
        final authorizationEpoch = requestedAuthorUid == ownerUid
            ? null
            : ref.read(_timelineHistoryAuthorizationEpochProvider);
        ref.invalidate(
          _timelineHistoryPageProvider((
            ownerUid: ownerUid,
            authorUid: requestedAuthorUid,
            authorizationEpoch: authorizationEpoch,
          )),
        );
        ref.invalidate(authorizedHistoryProvider(requestedAuthorUid));
      };
    });
