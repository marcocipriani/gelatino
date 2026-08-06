import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/router_auth_provider.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/timeline_repository.dart';
import 'package:gelatino/router.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/authenticated_shell.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('/ redirects to /collection inside the authenticated shell', (
    tester,
  ) async {
    final harness = await _pumpAppRouter(tester);

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/collection',
    );
    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(_isSelected(tester, '/collection'), isTrue);
  });

  for (final route in <String>[
    '/collection',
    '/timeline',
    '/places',
    '/friends',
  ]) {
    testWidgets('a refresh on $route preserves route-selected shell state', (
      tester,
    ) async {
      final harness = await _pumpAppRouter(tester, initialRoute: route);

      expect(harness.router.routeInformationProvider.value.uri.path, route);
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(_isSelected(tester, route), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('direct primary deep links preserve location and selection', (
    tester,
  ) async {
    final harness = await _pumpAppRouter(tester);

    for (final route in <String>[
      '/collection',
      '/timeline',
      '/places',
      '/friends',
    ]) {
      harness.router.go(route);
      await tester.pumpAndSettle();

      expect(harness.router.routeInformationProvider.value.uri.path, route);
      expect(find.byType(AuthenticatedShell), findsOneWidget);
      expect(_isSelected(tester, route), isTrue);
      if (route == '/friends') {
        expect(find.textContaining('I miei amici'), findsNothing);
      }
      expect(tester.takeException(), isNull, reason: route);
    }
  });

  testWidgets('destination taps and platform route restoration select by URL', (
    tester,
  ) async {
    final harness = await _pumpAppRouter(tester);

    await tester.tap(find.byKey(const ValueKey('nav-/timeline')));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/timeline');
    expect(_isSelected(tester, '/timeline'), isTrue);

    await tester.tap(find.byKey(const ValueKey('nav-/friends')));
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/friends');
    expect(_isSelected(tester, '/friends'), isTrue);

    // This is the platform RouteInformation update used for browser history.
    final restoredConfiguration = await harness.router.routeInformationParser
        .parseRouteInformationWithDependencies(
          RouteInformation(uri: Uri.parse('/timeline')),
          tester.element(find.byType(AuthenticatedShell)),
        );
    await harness.router.routerDelegate.setNewRoutePath(restoredConfiguration);
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/timeline');
    expect(_isSelected(tester, '/timeline'), isTrue);
  });

  testWidgets('guest /join redirect remains exact and does not loop', (
    tester,
  ) async {
    final session = _FakeRouterAuthSession();
    final harness = await _pumpAppRouter(tester, session: session);

    harness.router.go('/join?by=bob');
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/login?redirect=%2Fjoin%3Fby%3Dbob',
    );

    session.authenticate('alice');
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/join?by=bob',
    );
    session.notifyAuthRefresh();
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/join?by=bob',
    );
  });

  for (final layoutCase in <({Size size, bool wide})>[
    (size: const Size(1024, 900), wide: true),
    (size: const Size(768, 1024), wide: false),
  ]) {
    testWidgets(
      'real shell preserves Timeline breakpoint at ${layoutCase.size.width}',
      (tester) async {
        final harness = await _pumpAppRouter(
          tester,
          initialRoute: '/timeline',
          size: layoutCase.size,
          timelineRepository: _RouterTimelineRepository(_routerPage),
        );
        if (layoutCase.wide) {
          expect(
            find.byKey(const ValueKey('timeline-wide-feed')),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('timeline-wide-feed')))
                .width,
            680,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('timeline-friends-sidebar')))
                .width,
            280,
          );
        } else {
          expect(
            find.byKey(const ValueKey('timeline-medium-feed')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('timeline-friends-sidebar')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('timeline-compact-deck')),
            findsNothing,
          );
        }
        await harness.close(tester);
      },
    );
  }

  for (final loadingCase in <({Size size, double sidebarWidth})>[
    (size: const Size(1024, 900), sidebarWidth: 280),
    (size: const Size(1440, 1000), sidebarWidth: 304),
  ]) {
    testWidgets(
      'real shell loading keeps ${loadingCase.sidebarWidth} sidebar at '
      '${loadingCase.size.width}',
      (tester) async {
        final repository = _PendingRouterTimelineRepository();
        final harness = await _pumpAppRouter(
          tester,
          initialRoute: '/timeline',
          size: loadingCase.size,
          timelineRepository: repository,
          settle: false,
        );
        expect(
          find.byKey(const ValueKey('timeline-wide-feed')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('timeline-friends-sidebar')))
              .width,
          loadingCase.sidebarWidth,
        );
        expect(tester.takeException(), isNull);
        repository.complete();
        await tester.pumpAndSettle();
        await harness.close(tester);
      },
    );
  }

  test('primary navigation has no tab-index state source', () {
    final navigation = File(
      'lib/providers/navigation_provider.dart',
    ).readAsStringSync();
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final collection = File(
      'lib/screens/collection_screen.dart',
    ).readAsStringSync();

    expect(navigation, isNot(contains('mainTabProvider')));
    expect(main, isNot(contains('mainTabProvider')));
    expect(collection, isNot(contains('mainTabProvider')));
    expect(collection, contains("context.go('/places')"));
  });
}

bool _isSelected(WidgetTester tester, String route) =>
    tester
        .getSemantics(find.byKey(ValueKey('nav-$route')))
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

Future<_RouterHarness> _pumpAppRouter(
  WidgetTester tester, {
  _FakeRouterAuthSession? session,
  String? initialRoute,
  Size size = const Size(390, 844),
  TimelineRepository? timelineRepository,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authSession = session ?? _FakeRouterAuthSession('alice');
  final container = ProviderContainer(
    overrides: [
      routerAuthSessionProvider.overrideWithValue(authSession),
      currentUidProvider.overrideWithValue(
        timelineRepository == null ? null : 'alice',
      ),
      currentUserProvider.overrideWithValue(null),
      ownProfileProvider.overrideWith((ref) => Stream.value(null)),
      ownSettingsProvider.overrideWith((ref) => Stream.value(null)),
      publicProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
      friendsBadgeCountProvider.overrideWithValue(0),
      savedPlacesProvider.overrideWithValue(
        const AsyncData<List<Place>>(<Place>[]),
      ),
      placesProvider.overrideWith(
        (ref) => Stream<List<Place>>.value(const <Place>[]),
      ),
      if (timelineRepository != null) ...[
        acceptedFriendsProvider.overrideWithValue(
          const AsyncData(<String>['bob']),
        ),
        timelineRepositoryProvider.overrideWithValue(timelineRepository),
        friendsActivityProvider.overrideWithValue(
          const AsyncData(<FriendActivity>[]),
        ),
        storageServiceProvider.overrideWithValue(
          StorageService.forTesting(_RouterMediaGateway()),
        ),
      ],
    ],
  );
  final router = container.read(appRouterProvider);
  if (initialRoute != null) router.go(initialRoute);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  final harness = _RouterHarness(router, container);
  addTearDown(harness.dispose);
  return harness;
}

final class _RouterHarness {
  _RouterHarness(this.router, this.container);

  final GoRouter router;
  final ProviderContainer container;
  bool _closed = false;

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    dispose();
    await tester.pump();
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    container.dispose();
  }
}

final class _FakeRouterAuthSession extends ChangeNotifier
    implements RouterAuthSession {
  _FakeRouterAuthSession([this._uid]);

  String? _uid;

  @override
  String? get uid => _uid;

  void authenticate(String uid) {
    _uid = uid;
    notifyListeners();
  }

  void notifyAuthRefresh() => notifyListeners();

  @override
  Future<void> signInWithGoogle() async {}
}

final _routerPage = FeedPage(
  items: <FeedItem>[_routerItem],
  cursor: null,
  hasMore: false,
);

final _routerItem = FeedItem.fromMap(<String, dynamic>{
  'author_uid': 'alice',
  'check_in_id': 'checkin00000000000000001',
  'user_snapshot': <String, dynamic>{
    'display_name': 'Ada',
    'username': 'ada',
    'avatar_path': null,
  },
  'place_id': 'place-1',
  'place_snapshot': <String, dynamic>{
    'name': 'Gelateria Uno',
    'address': 'Via Roma 1',
  },
  'gelato_type': <String, dynamic>{'id': 'cono', 'name': 'Cono'},
  'flavors': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
  ],
  'rating': 5,
  'review_text': '',
  'tagged_user_ids': const <String>[],
  'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
  'photo_storage_path': 'check_ins/alice/checkin00000000000000001/photo.jpg',
}, 'checkin00000000000000001');

final class _RouterTimelineRepository implements TimelineRepository {
  const _RouterTimelineRepository(this.page);

  final FeedPage page;

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) async => page;

  @override
  Future<FeedPage> nextPage(
    String uid,
    FeedCursor cursor, {
    int limit = 20,
  }) async => page;

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) async => page;
}

final class _PendingRouterTimelineRepository implements TimelineRepository {
  _PendingRouterTimelineRepository();

  final Completer<FeedPage> _pending = Completer<FeedPage>();

  void complete() {
    if (!_pending.isCompleted) _pending.complete(_routerPage);
  }

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) => _pending.future;

  @override
  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20}) =>
      _pending.future;

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) => _pending.future;
}

final class _RouterMediaGateway implements StorageObjectGateway {
  @override
  Future<Uint8List?> read(String path, int maxBytes) async => null;

  @override
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata) =>
      throw UnimplementedError();
}
