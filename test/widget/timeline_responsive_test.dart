import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/feed_item.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/repositories/timeline_repository.dart';
import 'package:gelatino/screens/timeline_screen.dart';
import 'package:gelatino/services/storage_service.dart';
import 'package:gelatino/widgets/authenticated_check_in_photo.dart';
import 'package:gelatino/widgets/share/share_check_in_card.dart';
import 'package:gelatino/widgets/timeline/timeline_compact_deck.dart';
import 'package:gelatino/widgets/timeline/timeline_editorial_card.dart';

void main() {
  test('deck direction gives threshold velocity precedence over drag sign', () {
    expect(timelineDeckNavigationDirection(dragOffset: -1, velocity: 451), -1);
    expect(timelineDeckNavigationDirection(dragOffset: 1, velocity: -451), 1);
    expect(timelineDeckNavigationDirection(dragOffset: -64, velocity: -450), 0);
    expect(timelineDeckNavigationDirection(dragOffset: -65, velocity: 0), 1);
  });

  test('timeline source preserves private controller boundary', () {
    final source = File('lib/screens/timeline_screen.dart').readAsStringSync();
    final provider = File(
      'lib/providers/timeline_providers.dart',
    ).readAsStringSync();

    expect(source, contains('timelineProvider'));
    expect(source, isNot(contains('checkInsProvider')));
    expect(source, isNot(contains('check_ins')));
    expect(provider, contains('friendsActivityProvider'));
    expect(provider, isNot(contains('checkInsProvider')));
  });

  for (final size in <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 900),
    const Size(1440, 1000),
  ]) {
    testWidgets('timeline has bounded geometry at ${size.width}', (
      tester,
    ) async {
      await _pumpTimeline(tester, size: size, items: _items(4));
      expect(tester.takeException(), isNull);
      if (size.width < 600) {
        expect(
          find.byKey(const ValueKey('timeline-compact-deck')),
          findsOneWidget,
        );
      } else if (size.width < 1024) {
        expect(
          find.byKey(const ValueKey('timeline-medium-feed')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timeline-friends-sidebar')),
          findsNothing,
        );
      } else {
        expect(
          find.byKey(const ValueKey('timeline-wide-feed')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timeline-friends-sidebar')),
          findsOneWidget,
        );
        final feed = tester.getSize(
          find.byKey(const ValueKey('timeline-wide-feed')),
        );
        final sidebar = tester.getSize(
          find.byKey(const ValueKey('timeline-friends-sidebar')),
        );
        expect(feed.width, 680);
        expect(sidebar.width, inInclusiveRange(280, 320));
        expect(
          tester
                  .getTopLeft(
                    find.byKey(const ValueKey('timeline-friends-sidebar')),
                  )
                  .dx -
              tester
                  .getTopRight(find.byKey(const ValueKey('timeline-wide-feed')))
                  .dx,
          32,
        );
      }
    });
  }

  testWidgets('editorial card keeps every field and authenticated photo', (
    tester,
  ) async {
    final gateway = _MediaGateway();
    await _pumpTimeline(
      tester,
      size: const Size(768, 1024),
      items: _items(1),
      gateway: gateway,
    );

    expect(find.text('Ada Gelato'), findsOneWidget);
    expect(find.text('15/07/2026'), findsOneWidget);
    expect(find.text('Gelateria Uno'), findsOneWidget);
    expect(find.text('Cono'), findsOneWidget);
    expect(find.text('Pistacchio'), findsOneWidget);
    expect(find.text('Nocciola'), findsOneWidget);
    expect(find.text('Cremoso e pulito.'), findsOneWidget);
    expect(find.text('4 su 5'), findsOneWidget);
    expect(
      gateway.reads,
      contains('check_ins/alice/checkin00000000000000001/photo.jpg'),
    );
    expect(
      tester.getSemantics(find.byType(AuthenticatedCheckInPhoto)).label,
      contains('Foto del check-in da Gelateria Uno'),
    );
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
  });

  testWidgets('share icon opens a branded preview with a Condividi action', (
    tester,
  ) async {
    await _pumpTimeline(tester, size: const Size(768, 1024), items: _items(1));

    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ShareCheckInCard), findsOneWidget);
    expect(find.text('Gelateria Uno'), findsWidgets);
    expect(find.text('Pistacchio'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Condividi'), findsOneWidget);
  });

  testWidgets(
    'compact mounts three cards, exposes current only and peeks 40 px',
    (tester) async {
      final gateway = _MediaGateway();
      await _pumpTimeline(
        tester,
        size: const Size(390, 844),
        items: _items(5),
        gateway: gateway,
      );

      expect(find.byType(TimelineEditorialCard), findsNWidgets(2));
      expect(find.bySemanticsLabel('Check-in 1 di 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Check-in 2 di 5'), findsNothing);
      expect(
        gateway.reads,
        contains('check_ins/bob/checkin00000000000000002/photo.jpg'),
      );
      final deckBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('timeline-compact-deck')))
          .dy;
      final nextTop = tester
          .getTopLeft(
            find.byKey(
              const ValueKey('timeline-deck-card-checkin00000000000000002'),
            ),
          )
          .dy;
      expect(deckBottom - nextTop, closeTo(40, 0.1));

      final previous = tester.getSize(
        find.byKey(const ValueKey('timeline-previous')),
      );
      final next = tester.getSize(find.byKey(const ValueKey('timeline-next')));
      expect(previous.width, greaterThanOrEqualTo(44));
      expect(previous.height, greaterThanOrEqualTo(44));
      expect(next.width, greaterThanOrEqualTo(44));
      expect(next.height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets('compact drag thresholds and 480ms settle advance exactly one', (
    tester,
  ) async {
    await _pumpTimeline(tester, size: const Size(390, 844), items: _items(5));
    final deck = find.byKey(const ValueKey('timeline-compact-deck'));

    await tester.timedDrag(
      deck,
      const Offset(0, -60),
      const Duration(milliseconds: 500),
    );
    await tester.pump(const Duration(milliseconds: 500));
    _expectCurrent(tester, 1, 5);

    await tester.timedDrag(
      deck,
      const Offset(0, -80),
      const Duration(milliseconds: 300),
    );
    await tester.pump(const Duration(milliseconds: 479));
    _expectCurrent(tester, 1, 5);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 2, 5);

    await tester.fling(deck, const Offset(0, -20), 500);
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 3, 5);
    await tester.fling(deck, const Offset(0, 20), 500);
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 2, 5);
  });

  testWidgets(
    'compact long card gives drag fling and wheel to internal scroll',
    (tester) async {
      final long = _longItem();
      await _pumpTimeline(
        tester,
        size: const Size(390, 500),
        items: <FeedItem>[long, ..._items(2)],
        textScaler: const TextScaler.linear(2),
      );
      final scroll = find.byKey(
        const ValueKey('timeline-card-scroll-checkin99999999999999999'),
      );
      final scrollable = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.timedDrag(
        scroll,
        const Offset(0, -100),
        const Duration(milliseconds: 700),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      _expectCurrentId(
        tester,
        'checkin99999999999999999',
        position: 1,
        total: 3,
      );

      final afterDrag = position.pixels;
      await tester.fling(scroll, const Offset(0, -80), 700);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(afterDrag));
      _expectCurrentId(
        tester,
        'checkin99999999999999999',
        position: 1,
        total: 3,
      );

      final afterFling = position.pixels;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(scroll),
          scrollDelta: const Offset(0, 30),
        ),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(afterFling));
      _expectCurrentId(
        tester,
        'checkin99999999999999999',
        position: 1,
        total: 3,
      );

      await tester.timedDrag(
        find.text('Ada dalla gelateria artigianale più lunga della città'),
        const Offset(0, -80),
        const Duration(milliseconds: 300),
      );
      await tester.pump(timelineDeckSettleDuration);
      await tester.pumpAndSettle();
      _expectCurrentId(
        tester,
        'checkin00000000000000001',
        position: 2,
        total: 3,
      );
    },
  );

  testWidgets(
    'compact wheel routes header viewport and boundary exactly once',
    (tester) async {
      final long = _longItem();
      await _pumpTimeline(
        tester,
        size: const Size(390, 500),
        items: <FeedItem>[long, ..._items(3)],
        textScaler: const TextScaler.linear(2),
      );
      final scroll = find.byKey(
        const ValueKey('timeline-card-scroll-checkin99999999999999999'),
      );
      final scrollable = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final header = tester.getCenter(
        find.text('Ada dalla gelateria artigianale più lunga della città'),
      );
      position.jumpTo(position.maxScrollExtent / 4);
      await tester.pump();

      final beforeHeader = position.pixels;
      await tester.sendEventToBinding(
        PointerScrollEvent(position: header, scrollDelta: const Offset(0, 30)),
      );
      await tester.pump();
      expect(position.pixels, closeTo(beforeHeader + 30, 0.1));
      _expectCurrentId(
        tester,
        'checkin99999999999999999',
        position: 1,
        total: 4,
      );

      final beforeViewport = position.pixels;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(scroll),
          scrollDelta: const Offset(0, 30),
        ),
      );
      await tester.pump();
      expect(position.pixels, closeTo(beforeViewport + 30, 0.1));
      _expectCurrentId(
        tester,
        'checkin99999999999999999',
        position: 1,
        total: 4,
      );

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.sendEventToBinding(
        PointerScrollEvent(position: header, scrollDelta: const Offset(0, 30)),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(position: header, scrollDelta: const Offset(0, 30)),
      );
      await tester.pump(timelineDeckSettleDuration);
      await tester.pumpAndSettle();
      _expectCurrentId(
        tester,
        'checkin00000000000000001',
        position: 2,
        total: 4,
      );
    },
  );

  testWidgets('compact ignores a gesture whose pointer starts during settle', (
    tester,
  ) async {
    await _pumpTimeline(tester, size: const Size(390, 844), items: _items(4));
    await tester.tap(find.byKey(const ValueKey('timeline-next')));
    await tester.pump(const Duration(milliseconds: 100));

    final deck = find.byKey(const ValueKey('timeline-compact-deck'));
    final gesture = await tester.startGesture(
      tester.getTopLeft(deck) + const Offset(4, 220),
    );
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.up();
    await tester.pump(timelineDeckSettleDuration);
    await tester.pumpAndSettle();

    _expectCurrent(tester, 2, 4);
  });

  testWidgets('compact keyboard, buttons, bounds and wheel lock', (
    tester,
  ) async {
    await _pumpTimeline(tester, size: const Size(390, 844), items: _items(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 2, 4);

    await tester.tap(find.byKey(const ValueKey('timeline-previous')));
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 1, 4);
    await tester.tap(find.byKey(const ValueKey('timeline-previous')));
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 1, 4);

    final center = tester.getCenter(
      find.byKey(const ValueKey('timeline-compact-deck')),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 20)),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 20)),
    );
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 2, 4);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 20)),
    );
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pumpAndSettle();
    _expectCurrent(tester, 3, 4);
  });

  testWidgets('compact reduced motion advances immediately without overshoot', (
    tester,
  ) async {
    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: _items(3),
      disableAnimations: true,
    );

    await tester.tap(find.byKey(const ValueKey('timeline-next')));
    await tester.pump();
    expect(find.bySemanticsLabel('Check-in 2 di 3'), findsOneWidget);
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey('timeline-deck-card-checkin00000000000000002'),
            ),
          )
          .dy,
      greaterThanOrEqualTo(0),
    );
  });

  testWidgets(
    'compact settles through a 10 px overshoot and reduced motion does not',
    (tester) async {
      await _pumpTimeline(tester, size: const Size(390, 844), items: _items(4));
      final second = find.byKey(
        const ValueKey('timeline-deck-card-checkin00000000000000002'),
      );

      await tester.tap(find.byKey(const ValueKey('timeline-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 403));
      expect(tester.getTopLeft(second).dy, closeTo(-2, 1.2));
      await tester.pump(const Duration(milliseconds: 77));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(second).dy, closeTo(8, 0.1));

      await _pumpTimeline(
        tester,
        size: const Size(390, 844),
        items: _items(4),
        disableAnimations: true,
      );
      await tester.tap(find.byKey(const ValueKey('timeline-next')));
      await tester.pump(const Duration(milliseconds: 403));
      expect(tester.getTopLeft(second).dy, closeTo(8, 0.1));
    },
  );

  testWidgets(
    'central deck mounts exactly previous current next and exposes current only',
    (tester) async {
      final gateway = _MediaGateway();
      await _pumpTimeline(
        tester,
        size: const Size(390, 844),
        items: _items(5),
        gateway: gateway,
      );
      await tester.tap(find.byKey(const ValueKey('timeline-next')));
      await tester.pump(const Duration(milliseconds: 480));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineEditorialCard), findsNWidgets(3));
      expect(find.bySemanticsLabel('Check-in 2 di 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Check-in 1 di 5'), findsNothing);
      expect(find.bySemanticsLabel('Check-in 3 di 5'), findsNothing);
      expect(
        gateway.reads,
        contains('check_ins/alice/checkin00000000000000003/photo.jpg'),
      );
    },
  );

  testWidgets(
    'penultimate paginates once, retry is explicit and append preserves ID',
    (tester) async {
      final model = _DeckModel(_items(5))..failNext = true;
      await _pumpDeck(tester, model);

      for (var step = 0; step < 3; step++) {
        await tester.tap(find.byKey(const ValueKey('timeline-next')));
        await tester.pump(const Duration(milliseconds: 480));
        await tester.pumpAndSettle();
      }
      expect(model.loadCalls, 1);
      expect(find.byKey(const ValueKey('timeline-retry-page')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      expect(model.loadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('timeline-retry-page')));
      await tester.pumpAndSettle();
      expect(model.loadCalls, 2);
      model.append(_items(7));
      await tester.pumpAndSettle();
      _expectCurrent(tester, 4, 7);
    },
  );

  testWidgets('wide friend activity is bounded and sticky while feed scrolls', (
    tester,
  ) async {
    final activities = List<FriendActivity>.generate(
      20,
      (index) => FriendActivity(
        profile: _profile(index),
        latestItem: _item(index + 1, author: index.isEven ? 'alice' : 'bob'),
      ),
    );
    await _pumpTimeline(
      tester,
      size: const Size(1024, 900),
      items: _items(8),
      activities: AsyncData(activities),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Persona 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-friends-list')), findsOneWidget);
    final sidebar = find.byKey(const ValueKey('timeline-friends-sidebar'));
    final topBefore = tester.getTopLeft(sidebar).dy;
    await tester.drag(
      find.byKey(const ValueKey('timeline-feed-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sidebar).dy, topBefore);
  });

  testWidgets('empty and failure states expose the correct useful action', (
    tester,
  ) async {
    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
      uid: null,
    );
    expect(find.text('Accedi'), findsOneWidget);

    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
      acceptedFriends: const AsyncData(<String>[]),
    );
    expect(find.text('Aggiungi amici'), findsOneWidget);

    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
    );
    expect(find.text('Fai check-in'), findsOneWidget);

    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
      firstError: const TimelineUnavailableFailure(),
    );
    expect(find.text('Riprova'), findsOneWidget);

    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
      acceptedFriends: const AsyncLoading<List<String>>(),
    );
    expect(find.text('Aggiornamento amicizie'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);

    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: const <FeedItem>[],
      acceptedFriends: AsyncError<List<String>>(
        StateError('authorization'),
        StackTrace.current,
      ),
    );
    expect(find.text('Amicizie non disponibili'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
  });

  testWidgets('friendship retry tap recreates sources and recovers Timeline', (
    tester,
  ) async {
    const size = Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final friendships = _RetryFriendshipRepository()
      ..profiles = <PublicProfile>[_friendProfile('bob')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          friendshipRepositoryProvider.overrideWithValue(friendships),
          timelineRepositoryProvider.overrideWithValue(
            _TimelineRepository(
              FeedPage(items: _items(2), cursor: null, hasMore: false),
            ),
          ),
          storageServiceProvider.overrideWithValue(
            StorageService.forTesting(_MediaGateway()),
          ),
        ],
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(friendships.watchCalls, 1);

    friendships.fail(StateError('friendships unavailable'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-wide-feed')), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);

    await tester.tap(find.text('Riprova'));
    await tester.pump();
    expect(friendships.watchCalls, 2);
    friendships.emit(<Friendship>[
      _friendship('alice', 'bob', state: FriendshipState.accepted),
    ]);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(friendships.profileReadCalls, 1);
    expect(find.byKey(const ValueKey('timeline-wide-feed')), findsOneWidget);
    expect(find.text('Amico bob'), findsOneWidget);
  });

  testWidgets('compact keeps pull-to-refresh available on the first card', (
    tester,
  ) async {
    final model = _DeckModel(_items(5));
    await _pumpDeck(tester, model);

    await tester.drag(
      find.byKey(const ValueKey('timeline-compact-deck')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(model.refreshCalls, 1);
    _expectCurrent(tester, 1, 5);
  });

  testWidgets('compact and wide resist 200 percent text with long snapshots', (
    tester,
  ) async {
    final long = _longItem();
    await _pumpTimeline(
      tester,
      size: const Size(390, 844),
      items: <FeedItem>[long, ..._items(2)],
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSemantics(
            find.byKey(
              const ValueKey(
                'timeline-deck-semantics-checkin99999999999999999',
              ),
            ),
          )
          .label,
      contains('Check-in 1 di 3'),
    );

    await _pumpTimeline(
      tester,
      size: const Size(1024, 900),
      items: <FeedItem>[long, ..._items(5)],
      activities: AsyncData(
        List<FriendActivity>.generate(
          20,
          (index) => FriendActivity(
            profile: _profile(index, long: true),
            latestItem: long,
          ),
        ),
      ),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('timeline-friends-list')), findsOneWidget);
  });

  testWidgets('loading geometry keeps the final responsive shells', (
    tester,
  ) async {
    for (final size in <Size>[
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 900),
    ]) {
      await _pumpTimelineLoading(tester, size);
      expect(tester.takeException(), isNull);
      if (size.width < 600) {
        expect(
          find.byKey(const ValueKey('timeline-compact-deck')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('timeline-loading-card')))
              .height,
          closeTo(size.height - 56, 0.1),
        );
      } else if (size.width < 1024) {
        expect(
          find.byKey(const ValueKey('timeline-medium-feed')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const ValueKey('timeline-wide-feed')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timeline-friends-sidebar')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('timeline-wide-feed')))
              .width,
          680,
        );
      }
    }
  });
}

Future<void> _pumpTimeline(
  WidgetTester tester, {
  required Size size,
  required List<FeedItem> items,
  _MediaGateway? gateway,
  bool disableAnimations = false,
  String? uid = 'alice',
  AsyncValue<List<String>> acceptedFriends = const AsyncData(<String>['bob']),
  AsyncValue<List<FriendActivity>> activities = const AsyncData(
    <FriendActivity>[],
  ),
  TimelineFailure? firstError,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final media = gateway ?? _MediaGateway();
  final repository = _TimelineRepository(
    FeedPage(
      items: items,
      cursor: items.isEmpty
          ? null
          : const FeedCursor(ownerUid: 'alice', token: 'p1'),
      hasMore: false,
    ),
    error: firstError,
  );
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        acceptedFriendsProvider.overrideWithValue(acceptedFriends),
        timelineRepositoryProvider.overrideWithValue(repository),
        friendsActivityProvider.overrideWithValue(activities),
        storageServiceProvider.overrideWithValue(
          StorageService.forTesting(media),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: const TimelineScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpDeck(WidgetTester tester, _DeckModel model) async {
  const size = Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(
          StorageService.forTesting(_MediaGateway()),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: Scaffold(
            body: AnimatedBuilder(
              animation: model,
              builder: (context, child) => TimelineCompactDeck(
                items: model.items,
                hasMore: model.hasMore,
                isLoadingMore: false,
                failure: model.failure,
                onLoadMore: model.loadMore,
                onRefresh: model.refresh,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTimelineLoading(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final pending = Completer<FeedPage>();
  final repository = _PendingTimelineRepository(pending.future);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        acceptedFriendsProvider.overrideWithValue(
          const AsyncData(<String>['bob']),
        ),
        timelineRepositoryProvider.overrideWithValue(repository),
        friendsActivityProvider.overrideWithValue(
          const AsyncLoading<List<FriendActivity>>(),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const TimelineScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<FeedItem> _items(int count) => List<FeedItem>.generate(
  count,
  (index) => _item(index + 1, author: index.isEven ? 'alice' : 'bob'),
);

FeedItem _item(int index, {required String author}) {
  final id = 'checkin${index.toString().padLeft(17, '0')}';
  return FeedItem.fromMap(<String, dynamic>{
    'author_uid': author,
    'check_in_id': id,
    'user_snapshot': <String, dynamic>{
      'display_name': index == 1 ? 'Ada Gelato' : 'Amico $index',
      'username': index == 1 ? 'ada' : 'amico$index',
      'avatar_path': 'avatars/$author/avatar.jpg',
    },
    'place_id': 'place-$index',
    'place_snapshot': <String, dynamic>{
      'name': index == 1 ? 'Gelateria Uno' : 'Gelateria $index',
      'address': 'Via Roma $index',
    },
    'gelato_type': <String, dynamic>{'id': 'cono', 'name': 'Cono'},
    'flavors': <Map<String, dynamic>>[
      <String, dynamic>{'id': 'pistacchio', 'name': 'Pistacchio'},
      <String, dynamic>{'id': 'nocciola', 'name': 'Nocciola'},
    ],
    'rating': 4,
    'review_text': index == 1 ? 'Cremoso e pulito.' : '',
    'tagged_user_ids': const <String>[],
    'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 16 - index)),
    'photo_storage_path': 'check_ins/$author/$id/photo.jpg',
  }, id);
}

FeedItem _longItem() {
  const id = 'checkin99999999999999999';
  return FeedItem.fromMap(<String, dynamic>{
    'author_uid': 'alice',
    'check_in_id': id,
    'user_snapshot': <String, dynamic>{
      'display_name': 'Ada dalla gelateria artigianale più lunga della città',
      'username': 'ada-lunga',
      'avatar_path': 'avatars/alice/avatar.jpg',
    },
    'place_id': 'place-long',
    'place_snapshot': <String, dynamic>{
      'name': 'Gelateria dal nome volutamente molto lungo e descrittivo',
      'address': 'Viale lunghissimo 999',
    },
    'gelato_type': <String, dynamic>{
      'id': 'coppa-grande',
      'name': 'Coppa grande artigianale',
    },
    'flavors': const <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'pistacchio-lungo',
        'name': 'Pistacchio di Bronte intenso',
      },
      <String, dynamic>{
        'id': 'nocciola-lunga',
        'name': 'Nocciola piemontese tostata',
      },
      <String, dynamic>{
        'id': 'cioccolato-lungo',
        'name': 'Cioccolato fondente monorigine',
      },
      <String, dynamic>{
        'id': 'vaniglia-lunga',
        'name': 'Vaniglia bourbon del Madagascar',
      },
    ],
    'rating': 5,
    'review_text':
        'Una recensione volutamente molto lunga che verifica il comportamento '
        'del layout quando il testo viene ingrandito al duecento per cento.',
    'tagged_user_ids': const <String>[],
    'created_at': Timestamp.fromDate(DateTime.utc(2026, 7, 16)),
    'photo_storage_path': 'check_ins/alice/$id/photo.jpg',
  }, id);
}

PublicProfile _profile(int index, {bool long = false}) {
  final uid = 'person$index';
  return PublicProfile.fromMap(<String, dynamic>{
    'uid': uid,
    'display_name': long
        ? 'Persona con un nome eccezionalmente lungo numero $index'
        : 'Persona $index',
    'display_name_lower': 'persona $index',
    'username': 'persona$index',
    'username_lower': 'persona$index',
    'avatar_path': 'avatars/$uid/avatar.jpg',
    'bio': '',
    'city': 'Milano',
    'favorite_place_id': null,
    'favorite_flavor_id': null,
    'favorite_flavor_ids': const <String>[],
    'profile_visibility': 'friends',
    'searchable': true,
    'points': index,
    'updated_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
  }, uid);
}

PublicProfile _friendProfile(String uid) =>
    PublicProfile.fromMap(<String, dynamic>{
      'uid': uid,
      'display_name': 'Amico $uid',
      'display_name_lower': 'amico $uid',
      'username': uid,
      'username_lower': uid,
      'avatar_path': null,
      'bio': '',
      'city': 'Roma',
      'favorite_place_id': null,
      'favorite_flavor_id': null,
      'favorite_flavor_ids': const <String>[],
      'profile_visibility': 'friends',
      'searchable': true,
      'points': 0,
      'updated_at': Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
    }, uid);

Friendship _friendship(
  String requester,
  String recipient, {
  required FriendshipState state,
}) {
  final now = Timestamp.fromDate(DateTime.utc(2026, 7, 15));
  final members = <String>[requester, recipient]..sort();
  return Friendship.fromMap(
    <String, dynamic>{
      'member_uids': members,
      'requester_uid': requester,
      'recipient_uid': recipient,
      'state': state.name,
      'requested_at': now,
      'responded_at': now,
      'accepted_at': now,
      'removed_at': null,
      'affinity_score': 0,
      'updated_at': now,
    },
    'YWxpY2U.Ym9i',
    callerUid: requester,
  );
}

final class _DeckModel extends ChangeNotifier {
  _DeckModel(this.items);

  List<FeedItem> items;
  bool hasMore = true;
  bool failNext = false;
  int loadCalls = 0;
  int refreshCalls = 0;
  TimelineFailure? failure;

  Future<void> loadMore() async {
    loadCalls++;
    if (failNext) {
      failNext = false;
      failure = const TimelineUnavailableFailure();
      notifyListeners();
      return;
    }
    failure = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    refreshCalls++;
  }

  void append(List<FeedItem> next) {
    items = next;
    hasMore = false;
    failure = null;
    notifyListeners();
  }
}

final class _TimelineRepository implements TimelineRepository {
  const _TimelineRepository(this.page, {this.error});

  final FeedPage page;
  final TimelineFailure? error;

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) async {
    if (error case final failure?) throw failure;
    return page;
  }

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

final class _RetryFriendshipRepository implements FriendshipRepository {
  final StreamController<List<Friendship>> _controller =
      StreamController<List<Friendship>>.broadcast(sync: true);
  List<PublicProfile> profiles = const <PublicProfile>[];
  int watchCalls = 0;
  int profileReadCalls = 0;

  void emit(List<Friendship> relationships) => _controller.add(relationships);

  void fail(Object error) => _controller.addError(error);

  @override
  Stream<List<Friendship>> watchForUser(String uid) {
    watchCalls++;
    return _controller.stream;
  }

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async {
    profileReadCalls++;
    return profiles.where((profile) => uids.contains(profile.uid)).toList();
  }

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => false;

  @override
  Future<void> remove(String otherUid) async {}

  @override
  Future<void> respond(String otherUid, FriendResponse response) async {}

  @override
  Future<void> send(String otherUid) async {}
}

final class _PendingTimelineRepository implements TimelineRepository {
  const _PendingTimelineRepository(this.pending);

  final Future<FeedPage> pending;

  @override
  Future<FeedPage> firstPage(String uid, {int limit = 20}) => pending;

  @override
  Future<FeedPage> nextPage(String uid, FeedCursor cursor, {int limit = 20}) =>
      pending;

  @override
  Future<FeedPage> authorHistory(
    String ownerUid,
    String authorUid, {
    required Set<String> authorizedAuthorUids,
    int limit = 20,
  }) => pending;
}

final class _MediaGateway implements StorageObjectGateway {
  final List<String> reads = <String>[];

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    reads.add(path);
    return null;
  }

  @override
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata) =>
      throw UnimplementedError();
}

void _expectCurrent(WidgetTester tester, int index, int total) {
  final id = 'checkin${index.toString().padLeft(17, '0')}';
  _expectCurrentId(tester, id, position: index, total: total);
}

void _expectCurrentId(
  WidgetTester tester,
  String id, {
  required int position,
  required int total,
}) {
  final node = tester.getSemantics(
    find.byKey(ValueKey<String>('timeline-deck-semantics-$id')),
  );
  expect(node.label, contains('Check-in $position di $total'));
  expect(node.flagsCollection.isSelected, Tristate.isTrue);
}
