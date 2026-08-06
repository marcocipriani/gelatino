import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/friendship.dart';
import 'package:gelatino/models/gelato_invite.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/friendship_providers.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/repositories/friendship_repository.dart';
import 'package:gelatino/repositories/gelato_invite_repository.dart';
import 'package:gelatino/repositories/profile_repository.dart';
import 'package:gelatino/screens/friends_screen.dart';
import 'package:go_router/go_router.dart';

final _testFriendsUidProvider = NotifierProvider<_TestFriendsUid, String?>(
  _TestFriendsUid.new,
);
final _testInvitesProvider = NotifierProvider<_TestInvites, List<GelatoInvite>>(
  _TestInvites.new,
);

void main() {
  testWidgets(
    'Friends uses compact medium and wide A1 geometry without 200% overflow',
    (tester) async {
      for (final testCase in <({double width, String layout})>[
        (width: 390, layout: 'compact'),
        (width: 768, layout: 'medium'),
        (width: 1024, layout: 'wide'),
        (width: 1440, layout: 'wide'),
      ]) {
        tester.view.physicalSize = Size(testCase.width, 1000);
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          _friendsHarness(
            textScale: 2,
            friends: AsyncData<List<PublicProfile>>(<PublicProfile>[
              _publicProfile('bob', 'Bob'),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('friends-${testCase.layout}')),
          findsOneWidget,
        );
        expect(find.text('Con chi prendiamo un gelato?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Friends honors narrow constraints inside a wide MediaQuery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            height: 1000,
            child: _friendsHarness(includeMaterialApp: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('friends-compact')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friends-compact-content')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('friends-wide-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'external invite is accessible and copies an encoded URL in every layout',
    (tester) async {
      const uid = 'bob&team#1';
      final copiedTexts = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedTexts.add(
              (call.arguments as Map<Object?, Object?>)['text']! as String,
            );
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      for (final width in <double>[390, 768, 1024]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_friendsHarness(uid: uid));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('friends-external-invite')),
          findsOneWidget,
        );
        if (width >= 1024) {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('friends-wide-secondary')),
              matching: find.byKey(const ValueKey('friends-external-invite')),
            ),
            findsOneWidget,
          );
        }
        final copyFinder = find.byKey(
          const ValueKey('friends-external-invite-copy'),
        );
        expect(copyFinder, findsOneWidget);
        expect(tester.getSize(copyFinder).height, greaterThanOrEqualTo(48));
        expect(
          tester.getSemantics(copyFinder).label,
          contains('Copia link invito'),
        );

        tester.widget<ButtonStyleButton>(copyFinder).onPressed!();
        await tester.pumpAndSettle();

        expect(copiedTexts.last, buildExternalInviteUri(uid).toString());
        final feedbackFinder = find.byKey(
          const ValueKey('friends-external-invite-feedback'),
        );
        expect(feedbackFinder, findsOneWidget);
        expect(
          tester.getSemantics(feedbackFinder).label,
          contains('Link invito copiato'),
        );
        expect(
          tester.widget<Semantics>(feedbackFinder).properties.liveRegion,
          isTrue,
        );
      }

      expect(copiedTexts, hasLength(3));
      expect(copiedTexts, everyElement(contains('bob%26team%231')));
    },
  );

  testWidgets('stale external invite copy never announces old UID feedback', (
    tester,
  ) async {
    final clipboardGate = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') await clipboardGate.future;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_friendsHarness(dynamicUid: true));
    await tester.pumpAndSettle();

    tester
        .widget<ButtonStyleButton>(
          find.byKey(const ValueKey('friends-external-invite-copy')),
        )
        .onPressed!();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FriendsScreen)),
    );
    container.read(_testFriendsUidProvider.notifier).set('zoe');
    await tester.pump();
    clipboardGate.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('friends-external-invite-feedback')),
      findsNothing,
    );
  });

  testWidgets('external invite copy failure is accessible and sanitized', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(
            code: 'clipboard',
            message: 'raw clipboard secret',
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_friendsHarness());
    await tester.pumpAndSettle();

    tester
        .widget<ButtonStyleButton>(
          find.byKey(const ValueKey('friends-external-invite-copy')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    const safeMessage = 'Impossibile copiare il link. Riprova.';
    expect(find.text(safeMessage), findsOneWidget);
    expect(find.textContaining('raw clipboard secret'), findsNothing);
    final feedbackFinder = find.byKey(
      const ValueKey('friends-external-invite-feedback'),
    );
    expect(tester.getSemantics(feedbackFinder).label, contains(safeMessage));
    expect(
      tester.widget<Semantics>(feedbackFinder).properties.liveRegion,
      isTrue,
    );
  });

  testWidgets('Friends exposes independent actionable errors and retries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _friendsHarness(
        friends: AsyncError<List<PublicProfile>>(
          StateError('friends raw backend'),
          StackTrace.current,
        ),
        requests: AsyncError<List<Friendship>>(
          StateError('requests raw backend'),
          StackTrace.current,
        ),
        invites: AsyncError<List<GelatoInvite>>(
          StateError('invites raw backend'),
          StackTrace.current,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amici non disponibili'), findsOneWidget);
    expect(find.text('Richieste non disponibili'), findsOneWidget);
    expect(find.text('Inviti non disponibili'), findsOneWidget);
    expect(find.byKey(const ValueKey('friends-retry-friends')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friends-retry-requests')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('friends-retry-invites')), findsOneWidget);
    expect(find.textContaining('raw backend'), findsNothing);
  });

  testWidgets('newer Friends search wins over a stale completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profiles = _DeferredProfiles();

    await tester.pumpWidget(_friendsHarness(profiles: profiles));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ca');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    profiles.complete(1, <PublicProfile>[_publicProfile('carol', 'Carol')]);
    await tester.pump();
    expect(find.text('Carol'), findsOneWidget);

    profiles.complete(0, <PublicProfile>[_publicProfile('bob', 'Bob')]);
    await tester.pump();

    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('search exposes all reciprocal relationship labels', (
    tester,
  ) async {
    final profiles = _DeferredProfiles();
    await tester.pumpWidget(
      _friendsHarness(
        profiles: profiles,
        accepted: const AsyncData<List<String>>(<String>['amy']),
        requests: AsyncData<List<Friendship>>(<Friendship>[
          _friendship(requester: 'bob', recipient: 'alice'),
        ]),
        outgoing: AsyncData<List<Friendship>>(<Friendship>[
          _friendship(requester: 'alice', recipient: 'carol'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'persona');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    profiles.complete(0, <PublicProfile>[
      _publicProfile('amy', 'Amy'),
      _publicProfile('bob', 'Bob'),
      _publicProfile('carol', 'Carol'),
      _publicProfile('dave', 'Dave'),
    ]);
    await tester.pump();

    expect(find.text('Amico'), findsOneWidget);
    expect(find.text('Da accettare'), findsOneWidget);
    expect(find.text('In attesa'), findsOneWidget);
    expect(find.text('Aggiungi'), findsOneWidget);
  });

  testWidgets('unknown relationship loading never exposes friend send', (
    tester,
  ) async {
    final cases =
        <
          ({
            AsyncValue<List<String>> accepted,
            AsyncValue<List<Friendship>> requests,
            AsyncValue<List<Friendship>> outgoing,
          })
        >[
          (
            accepted: const AsyncLoading<List<String>>(),
            requests: const AsyncData<List<Friendship>>(<Friendship>[]),
            outgoing: const AsyncData<List<Friendship>>(<Friendship>[]),
          ),
          (
            accepted: const AsyncData<List<String>>(<String>[]),
            requests: const AsyncLoading<List<Friendship>>(),
            outgoing: const AsyncData<List<Friendship>>(<Friendship>[]),
          ),
          (
            accepted: const AsyncData<List<String>>(<String>[]),
            requests: const AsyncData<List<Friendship>>(<Friendship>[]),
            outgoing: const AsyncLoading<List<Friendship>>(),
          ),
          (
            accepted: const AsyncLoading<List<String>>(),
            requests: const AsyncLoading<List<Friendship>>(),
            outgoing: const AsyncLoading<List<Friendship>>(),
          ),
        ];

    for (final testCase in cases) {
      final profiles = _DeferredProfiles();
      await tester.pumpWidget(
        _friendsHarness(
          profiles: profiles,
          accepted: testCase.accepted,
          requests: testCase.requests,
          outgoing: testCase.outgoing,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dave');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      profiles.complete(0, <PublicProfile>[_publicProfile('dave', 'Dave')]);
      await tester.pump();

      expect(find.text('Verifica relazione…'), findsOneWidget);
      expect(find.text('Aggiungi'), findsNothing);
      expect(find.byKey(const ValueKey('friend-send-dave')), findsNothing);
    }
  });

  testWidgets('relationship errors fail closed with safe actionable retry', (
    tester,
  ) async {
    final relationError = StateError('relation backend secret');
    final stack = StackTrace.current;
    final cases =
        <
          ({
            AsyncValue<List<String>> accepted,
            AsyncValue<List<Friendship>> requests,
            AsyncValue<List<Friendship>> outgoing,
          })
        >[
          (
            accepted: AsyncError<List<String>>(relationError, stack),
            requests: const AsyncData<List<Friendship>>(<Friendship>[]),
            outgoing: const AsyncData<List<Friendship>>(<Friendship>[]),
          ),
          (
            accepted: const AsyncData<List<String>>(<String>[]),
            requests: AsyncError<List<Friendship>>(relationError, stack),
            outgoing: const AsyncData<List<Friendship>>(<Friendship>[]),
          ),
          (
            accepted: const AsyncData<List<String>>(<String>[]),
            requests: const AsyncData<List<Friendship>>(<Friendship>[]),
            outgoing: AsyncError<List<Friendship>>(relationError, stack),
          ),
          (
            accepted: AsyncError<List<String>>(relationError, stack),
            requests: AsyncError<List<Friendship>>(relationError, stack),
            outgoing: AsyncError<List<Friendship>>(relationError, stack),
          ),
        ];

    for (final testCase in cases) {
      final profiles = _DeferredProfiles();
      var refreshes = 0;
      await tester.pumpWidget(
        _friendsHarness(
          profiles: profiles,
          accepted: testCase.accepted,
          requests: testCase.requests,
          outgoing: testCase.outgoing,
          retryFriendships: () => refreshes++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dave');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      profiles.complete(0, <PublicProfile>[_publicProfile('dave', 'Dave')]);
      await tester.pump();

      expect(find.text('Relazione non disponibile'), findsOneWidget);
      expect(find.text('Aggiungi'), findsNothing);
      expect(find.byKey(const ValueKey('friend-send-dave')), findsNothing);
      expect(find.textContaining('backend secret'), findsNothing);
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('friends-retry-relationships')),
          )
          .onPressed!();
      expect(refreshes, 1);
    }
  });

  testWidgets('friend request is per-target single-flight with inline retry', (
    tester,
  ) async {
    final profiles = _DeferredProfiles();
    final friendships = _ActionFriendships()
      ..sendGate = Completer<void>()
      ..sendFailuresRemaining = 1;
    await tester.pumpWidget(
      _friendsHarness(profiles: profiles, friendships: friendships),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    profiles.complete(0, <PublicProfile>[_publicProfile('bob', 'Bob')]);
    await tester.pump();

    final send = tester.widget<FilledButton>(
      find.byKey(const ValueKey('friend-send-bob')),
    );
    send.onPressed!();
    send.onPressed!();
    await tester.pump();
    expect(friendships.sendCalls, <String>['bob']);

    friendships.sendGate!.complete();
    friendships.sendGate = null;
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Servizio amicizie non disponibile. Riprova.'),
      findsOneWidget,
    );

    tester
        .widget<TextButton>(
          find.byKey(const ValueKey('friend-action-retry-request-bob')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(friendships.sendCalls, <String>['bob', 'bob']);
    expect(find.text('In attesa'), findsOneWidget);
  });

  testWidgets('accept and decline refresh sources and remove stale cards', (
    tester,
  ) async {
    final friendships = _ActionFriendships();
    var refreshes = 0;
    await tester.pumpWidget(
      _friendsHarness(
        friendships: friendships,
        retryFriendships: () => refreshes++,
        requests: AsyncData<List<Friendship>>(<Friendship>[
          _friendship(requester: 'bob', recipient: 'alice'),
          _friendship(requester: 'carol', recipient: 'alice'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final acceptBob = find.byKey(const ValueKey('friend-request-accept-bob'));
    await tester.ensureVisible(acceptBob);
    await tester.pump();
    await tester.tap(acceptBob);
    await tester.pumpAndSettle();
    expect(friendships.responses, <String>['bob:accepted']);
    expect(find.text('Bob'), findsNothing);
    expect(refreshes, 1);

    final declineCarol = find.byKey(
      const ValueKey('friend-request-decline-carol'),
    );
    await tester.ensureVisible(declineCarol);
    await tester.pump();
    await tester.tap(declineCarol);
    await tester.pumpAndSettle();
    expect(friendships.responses, <String>['bob:accepted', 'carol:declined']);
    expect(find.text('Carol'), findsNothing);
    expect(refreshes, 2);
  });

  testWidgets('failed friend decline retries the same declined intent', (
    tester,
  ) async {
    final friendships = _ActionFriendships()..respondFailuresRemaining = 1;
    await tester.pumpWidget(
      _friendsHarness(
        friendships: friendships,
        requests: AsyncData<List<Friendship>>(<Friendship>[
          _friendship(requester: 'bob', recipient: 'alice'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final declineBob = find.byKey(
      const ValueKey('friend-request-decline-bob'),
    );
    await tester.ensureVisible(declineBob);
    await tester.pump();
    await tester.tap(declineBob);
    await tester.pumpAndSettle();
    tester
        .widget<TextButton>(
          find.byKey(const ValueKey('friend-action-retry-response-bob')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(friendships.responses, <String>['bob:declined', 'bob:declined']);
  });

  testWidgets('failed invite decline retries decline and never routes', (
    tester,
  ) async {
    final invites = _ActionInvites()..responseFailuresRemaining = 1;
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/friends',
      routes: [
        GoRoute(
          path: '/friends',
          builder: (_, _) => _friendsHarness(
            includeMaterialApp: false,
            inviteRepository: invites,
            invites: AsyncData<List<GelatoInvite>>(<GelatoInvite>[
              _invite('invite-bob', sender: 'bob'),
            ]),
          ),
        ),
        GoRoute(path: '/check-in', builder: (_, _) => const Text('CHECKIN')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('friend-invite-decline-invite-bob')),
    );
    await tester.pumpAndSettle();
    tester
        .widget<TextButton>(
          find.byKey(const ValueKey('friend-action-retry-invite-invite-bob')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(invites.responses, <String>[
      'invite-bob:declined',
      'invite-bob:declined',
    ]);
    expect(router.routeInformationProvider.value.uri.path, '/friends');
  });

  testWidgets('stale invite completion cannot resolve a rebound target', (
    tester,
  ) async {
    final invites = _ActionInvites()..responseGate = Completer<void>();
    await tester.pumpWidget(
      _friendsHarness(dynamicInvites: true, inviteRepository: invites),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('friend-invite-decline-shared-invite')),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FriendsScreen)),
    );
    container.read(_testInvitesProvider.notifier).set(<GelatoInvite>[
      _invite('shared-invite', sender: 'carol'),
    ]);
    await tester.pumpAndSettle();

    invites.responseGate!.complete();
    invites.responseGate = null;
    await tester.pumpAndSettle();

    expect(find.text('Carol'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('friend-invite-decline-shared-invite')),
          )
          .onPressed,
      isNotNull,
    );
    expect(invites.responses, <String>['shared-invite:declined']);
  });

  testWidgets('failed invite state is cleared when its ID rebinds target', (
    tester,
  ) async {
    final invites = _ActionInvites()..responseFailuresRemaining = 1;
    await tester.pumpWidget(
      _friendsHarness(dynamicInvites: true, inviteRepository: invites),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('friend-invite-decline-shared-invite')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Operazione non riuscita. Riprova.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friend-action-retry-invite-shared-invite')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FriendsScreen)),
    );
    container.read(_testInvitesProvider.notifier).set(<GelatoInvite>[
      _invite('shared-invite', sender: 'carol'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Operazione non riuscita. Riprova.'), findsNothing);
    expect(
      find.byKey(const ValueKey('friend-action-retry-invite-shared-invite')),
      findsNothing,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('friend-invite-decline-shared-invite')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'removing a friend requires confirmation and hides it on success',
    (tester) async {
      final friendships = _ActionFriendships();
      await tester.pumpWidget(
        _friendsHarness(
          friendships: friendships,
          friends: AsyncData<List<PublicProfile>>(<PublicProfile>[
            _publicProfile('bob', 'Bob'),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('friend-remove-bob')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Rimuovere Bob dagli amici?'), findsOneWidget);
      expect(friendships.removeCalls, isEmpty);

      await tester.tap(find.byKey(const ValueKey('friend-remove-confirm-bob')));
      await tester.pumpAndSettle();
      expect(friendships.removeCalls, <String>['bob']);
      expect(find.byKey(const ValueKey('friend-profile-bob')), findsNothing);
    },
  );

  testWidgets('friend remove dialog is inert after auth UID changes', (
    tester,
  ) async {
    final friendships = _ActionFriendships();
    await tester.pumpWidget(
      _friendsHarness(
        dynamicUid: true,
        friendships: friendships,
        friends: AsyncData<List<PublicProfile>>(<PublicProfile>[
          _publicProfile('bob', 'Bob'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<OutlinedButton>(find.byKey(const ValueKey('friend-remove-bob')))
        .onPressed!();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FriendsScreen)),
    );
    container.read(_testFriendsUidProvider.notifier).set('zoe');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend-remove-confirm-bob')));
    await tester.pumpAndSettle();

    expect(friendships.removeCalls, isEmpty);
  });

  testWidgets('Gelatino send is single-flight and disabled after success', (
    tester,
  ) async {
    final invites = _ActionInvites()..sendGate = Completer<void>();
    await tester.pumpWidget(
      _friendsHarness(
        inviteRepository: invites,
        friends: AsyncData<List<PublicProfile>>(<PublicProfile>[
          _publicProfile('bob', 'Bob'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final send = tester.widget<FilledButton>(
      find.byKey(const ValueKey('friend-invite-send-bob')),
    );
    send.onPressed!();
    send.onPressed!();
    await tester.pump();
    expect(invites.sendCalls, <String>['bob']);

    invites.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Invito inviato'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('friend-invite-send-bob')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('incoming invites accept once and decline never routes', (
    tester,
  ) async {
    final invites = _ActionInvites();
    var checkInBuilds = 0;
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/friends',
      routes: [
        GoRoute(
          path: '/friends',
          builder: (_, _) => _friendsHarness(
            includeMaterialApp: false,
            inviteRepository: invites,
            invites: AsyncData<List<GelatoInvite>>(<GelatoInvite>[
              _invite('invite-bob', sender: 'bob'),
              _invite('invite-carol', sender: 'carol'),
            ]),
          ),
        ),
        GoRoute(
          path: '/check-in',
          builder: (_, state) {
            checkInBuilds++;
            return Text(
              'CHECKIN:${state.uri.queryParameters['prefillFriendId']}',
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (_, state) =>
              Text('PROFILE:${state.uri.queryParameters['userId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final accept = tester.widget<FilledButton>(
      find.byKey(const ValueKey('friend-invite-accept-invite-bob')),
    );
    accept.onPressed!();
    accept.onPressed!();
    await tester.pump();
    expect(invites.responses, <String>['invite-bob:accepted']);

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('friend-invite-accept-invite-bob')),
      findsNothing,
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/check-in?prefillFriendId=bob',
    );
    expect(checkInBuilds, 1);

    router.go('/friends');
    await tester.pumpAndSettle();
    final decline = find.byKey(
      const ValueKey('friend-invite-decline-invite-carol'),
    );
    await tester.ensureVisible(decline);
    await tester.pump();
    await tester.tap(decline);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/friends');
    expect(invites.responses, contains('invite-carol:declined'));
    expect(find.text('Carol'), findsNothing);
  });

  testWidgets('profile navigation encodes reserved UID characters', (
    tester,
  ) async {
    const uid = 'bob&team#1';
    Uri? visitedProfileUri;
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/friends',
      routes: [
        GoRoute(
          path: '/friends',
          builder: (_, _) => _friendsHarness(
            includeMaterialApp: false,
            friends: AsyncData<List<PublicProfile>>(<PublicProfile>[
              _publicProfile(uid, 'Bob Reserved'),
            ]),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, state) {
            visitedProfileUri = state.uri;
            return Text('PROFILE:${state.uri.queryParameters['userId']}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final profile = find.byKey(const ValueKey('friend-profile-$uid'));
    tester
        .widget<InkWell>(
          find.descendant(of: profile, matching: find.byType(InkWell)).first,
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.text('PROFILE:$uid'), findsOneWidget);
    expect(visitedProfileUri?.queryParameters['userId'], uid);
    expect(visitedProfileUri.toString(), contains('bob%26team%231'));
  });
}

Widget _friendsHarness({
  double textScale = 1,
  String uid = 'alice',
  bool includeMaterialApp = true,
  AsyncValue<List<PublicProfile>> friends =
      const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
  AsyncValue<List<Friendship>> requests = const AsyncData<List<Friendship>>(
    <Friendship>[],
  ),
  AsyncValue<List<GelatoInvite>> invites = const AsyncData<List<GelatoInvite>>(
    <GelatoInvite>[],
  ),
  AsyncValue<List<String>> accepted = const AsyncData<List<String>>(<String>[]),
  AsyncValue<List<Friendship>> outgoing = const AsyncData<List<Friendship>>(
    <Friendship>[],
  ),
  ProfileRepository? profiles,
  FriendshipRepository friendships = const _FriendsRepository(),
  GelatoInviteRepository inviteRepository = const _InvitesRepository(),
  VoidCallback? retryFriendships,
  bool dynamicUid = false,
  bool dynamicInvites = false,
}) {
  final scope = ProviderScope(
    overrides: [
      if (dynamicUid)
        currentUidProvider.overrideWith(
          (ref) => ref.watch(_testFriendsUidProvider),
        )
      else
        currentUidProvider.overrideWithValue(uid),
      ownProfileProvider.overrideWith(
        (ref) => Stream<UserProfile?>.value(
          UserProfile(uid: 'alice', displayName: 'Alice', points: 10),
        ),
      ),
      friendshipRepositoryProvider.overrideWithValue(friendships),
      gelatoInviteRepositoryProvider.overrideWithValue(inviteRepository),
      if (profiles != null)
        profileRepositoryProvider.overrideWithValue(profiles),
      publicProfileProvider.overrideWith((ref, uid) {
        final name = uid.isEmpty
            ? 'Profilo'
            : '${uid[0].toUpperCase()}${uid.substring(1)}';
        return Stream<PublicProfile?>.value(_publicProfile(uid, name));
      }),
      friendshipsProvider.overrideWithValue(
        const AsyncData<List<Friendship>>(<Friendship>[]),
      ),
      acceptedFriendsProvider.overrideWithValue(accepted),
      acceptedFriendProfilesProvider.overrideWithValue(friends),
      incomingFriendRequestsProvider.overrideWithValue(requests),
      outgoingFriendRequestsProvider.overrideWithValue(outgoing),
      if (dynamicInvites)
        pendingIncomingGelatoInvitesProvider.overrideWith(
          (ref) =>
              AsyncData<List<GelatoInvite>>(ref.watch(_testInvitesProvider)),
        )
      else
        pendingIncomingGelatoInvitesProvider.overrideWithValue(invites),
      gelatoInviteHistoryProvider.overrideWithValue(
        const AsyncData<List<GelatoInvite>>(<GelatoInvite>[]),
      ),
      retryFriendshipSourcesProvider.overrideWithValue(
        retryFriendships ?? () {},
      ),
    ],
    child: const FriendsScreen(),
  );
  if (!includeMaterialApp) return scope;
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: scope,
  );
}

final class _DeferredProfiles implements ProfileRepository {
  final List<Completer<List<PublicProfile>>> _searches =
      <Completer<List<PublicProfile>>>[];

  void complete(int index, List<PublicProfile> profiles) {
    _searches[index].complete(profiles);
  }

  @override
  Future<List<PublicProfile>> searchPublicProfiles(
    String query, {
    int limit = 20,
  }) {
    final completer = Completer<List<PublicProfile>>();
    _searches.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PublicProfile _publicProfile(String uid, String displayName) =>
    PublicProfile.fromMap(<String, dynamic>{
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
      'points': 10,
      'updated_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    }, uid);

final class _FriendsRepository implements FriendshipRepository {
  const _FriendsRepository();

  @override
  Stream<List<Friendship>> watchForUser(String uid) =>
      Stream<List<Friendship>>.value(const <Friendship>[]);

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async =>
      const <PublicProfile>[];

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => false;

  @override
  Future<void> send(String otherUid) async {}

  @override
  Future<void> respond(String otherUid, FriendResponse response) async {}

  @override
  Future<void> remove(String otherUid) async {}
}

final class _InvitesRepository implements GelatoInviteRepository {
  const _InvitesRepository();

  @override
  Stream<List<GelatoInvite>> watchPendingIncoming(String uid) =>
      Stream<List<GelatoInvite>>.value(const <GelatoInvite>[]);

  @override
  Stream<List<GelatoInvite>> watchHistory(String uid) =>
      Stream<List<GelatoInvite>>.value(const <GelatoInvite>[]);

  @override
  Future<void> send(String receiverUid) async {}

  @override
  Future<void> respond(String inviteId, GelatoInviteStatus response) async {}
}

final class _ActionFriendships implements FriendshipRepository {
  final List<String> sendCalls = <String>[];
  final List<String> responses = <String>[];
  final List<String> removeCalls = <String>[];
  Completer<void>? sendGate;
  int sendFailuresRemaining = 0;
  int respondFailuresRemaining = 0;

  @override
  Stream<List<Friendship>> watchForUser(String uid) =>
      Stream<List<Friendship>>.value(const <Friendship>[]);

  @override
  Future<List<PublicProfile>> readPublicProfiles(List<String> uids) async =>
      const <PublicProfile>[];

  @override
  Future<bool> isAcceptedFriend(String uid, String otherUid) async => true;

  @override
  Future<void> send(String otherUid) async {
    sendCalls.add(otherUid);
    final gate = sendGate;
    if (gate != null) await gate.future;
    if (sendFailuresRemaining > 0) {
      sendFailuresRemaining--;
      throw const FriendshipUnavailableFailure();
    }
  }

  @override
  Future<void> respond(String otherUid, FriendResponse response) async {
    responses.add('$otherUid:${response.name}');
    if (respondFailuresRemaining > 0) {
      respondFailuresRemaining--;
      throw const FriendshipUnavailableFailure();
    }
  }

  @override
  Future<void> remove(String otherUid) async {
    removeCalls.add(otherUid);
  }
}

final class _ActionInvites implements GelatoInviteRepository {
  final List<String> sendCalls = <String>[];
  final List<String> responses = <String>[];
  Completer<void>? sendGate;
  Completer<void>? responseGate;
  int responseFailuresRemaining = 0;

  @override
  Stream<List<GelatoInvite>> watchPendingIncoming(String uid) =>
      Stream<List<GelatoInvite>>.value(const <GelatoInvite>[]);

  @override
  Stream<List<GelatoInvite>> watchHistory(String uid) =>
      Stream<List<GelatoInvite>>.value(const <GelatoInvite>[]);

  @override
  Future<void> send(String receiverUid) async {
    sendCalls.add(receiverUid);
    final gate = sendGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> respond(String inviteId, GelatoInviteStatus response) async {
    responses.add('$inviteId:${response.name}');
    final gate = responseGate;
    if (gate != null) await gate.future;
    if (responseFailuresRemaining > 0) {
      responseFailuresRemaining--;
      throw StateError('invite backend');
    }
  }
}

final class _TestFriendsUid extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final class _TestInvites extends Notifier<List<GelatoInvite>> {
  @override
  List<GelatoInvite> build() => <GelatoInvite>[
    _invite('shared-invite', sender: 'bob'),
  ];

  void set(List<GelatoInvite> value) => state = value;
}

Friendship _friendship({required String requester, required String recipient}) {
  final members = <String>[requester, recipient]..sort();
  final id = members.map(_encodedId).join('.');
  final now = DateTime(2026, 7, 15);
  return Friendship.fromMap(
    <String, dynamic>{
      'member_uids': members,
      'requester_uid': requester,
      'recipient_uid': recipient,
      'state': 'pending',
      'requested_at': Timestamp.fromDate(now),
      'responded_at': null,
      'accepted_at': null,
      'removed_at': null,
      'affinity_score': 0,
      'updated_at': Timestamp.fromDate(now),
    },
    id,
    callerUid: 'alice',
  );
}

GelatoInvite _invite(String id, {required String sender}) {
  final members = <String>['alice', sender]..sort();
  return GelatoInvite.fromMap(<String, dynamic>{
    'member_uids': members,
    'sender_id': sender,
    'receiver_id': 'alice',
    'status': 'pending',
    'created_at': Timestamp.fromDate(DateTime(2026, 7, 15)),
    'responded_at': null,
  }, id);
}

String _encodedId(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');
