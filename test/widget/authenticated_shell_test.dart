import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/widgets/authenticated_shell.dart';
import 'package:gelatino/widgets/editorial_top_navigation.dart';
import 'package:gelatino/widgets/floating_bottom_navigation.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final size in <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 900),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'shell at ${size.width.toInt()} uses the route-selected A1 navigation',
      (tester) async {
        await _pumpShell(tester, size: size, badgeCount: 3);

        final isWide = size.width >= 1024;
        expect(
          find.byType(EditorialTopNavigation),
          isWide ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(FloatingBottomNavigation),
          isWide ? findsNothing : findsOneWidget,
        );

        const routes = <String>[
          '/collection',
          '/timeline',
          '/places',
          '/friends',
        ];
        for (final route in routes) {
          final destination = find.byKey(ValueKey('nav-$route'));
          expect(destination, findsOneWidget);
          final target = tester.getSize(destination);
          expect(target.width, greaterThanOrEqualTo(44));
          expect(target.height, greaterThanOrEqualTo(44));
        }
        final destinationCenters = routes
            .map(
              (route) =>
                  tester.getCenter(find.byKey(ValueKey('nav-$route'))).dx,
            )
            .toList(growable: false);
        expect(
          destinationCenters,
          orderedEquals([...destinationCenters]..sort()),
        );

        final selected = tester.getSemantics(
          find.byKey(const ValueKey('nav-/collection')),
        );
        expect(selected.flagsCollection.isSelected, Tristate.isTrue);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('nav-/friends'))).label,
          contains('3'),
        );
        expect(find.byKey(const ValueKey('friends-badge')), findsOneWidget);
        final pin = find.byKey(const ValueKey('melt-pin'));
        final avatar = find.byKey(const ValueKey('profile-avatar'));
        final settings = find.byKey(const ValueKey('settings-gear-shell'));
        expect(pin, findsOneWidget);
        expect(avatar, findsOneWidget);
        expect(settings, findsOneWidget);
        for (final control in <Finder>[pin, avatar]) {
          final target = tester.getSize(control);
          expect(target.width, greaterThanOrEqualTo(44));
          expect(target.height, greaterThanOrEqualTo(44));
        }
        expect(tester.getSize(settings).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(settings).height, greaterThanOrEqualTo(48));
        expect(tester.getSemantics(settings).label, 'Apri impostazioni');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings-gear-focus-ring')),
            matching: find.byType(IconButton),
          ),
          findsOneWidget,
        );
        if (!isWide) {
          final pinX = tester.getCenter(pin).dx;
          expect(pinX, greaterThan(destinationCenters[1]));
          expect(pinX, lessThan(destinationCenters[2]));
          expect(
            tester.getTopLeft(pin).dy,
            lessThan(
              tester
                  .getTopLeft(find.byKey(const ValueKey('bottom-nav-surface')))
                  .dy,
            ),
          );
        } else {
          expect(
            tester.getCenter(pin).dx,
            greaterThan(destinationCenters.last),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('compact quick action and avatar route without becoming tabs', (
    tester,
  ) async {
    final router = await _pumpShell(
      tester,
      size: const Size(390, 844),
      badgeCount: 0,
    );

    expect(find.byKey(const ValueKey('friends-badge')), findsNothing);
    expect(
      find.byKey(const ValueKey('melt-pin')),
      findsOneWidget,
      reason: 'Melt Pin is one quick action outside the four destinations',
    );

    final settingsGear = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(const ValueKey('settings-gear-shell')),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!;
    settingsGear();
    settingsGear();
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/collection');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('melt-pin')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHECK-IN'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/collection');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-avatar')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/collection');
  });

  testWidgets('route changes update selected semantics without local state', (
    tester,
  ) async {
    final router = await _pumpShell(
      tester,
      size: const Size(768, 1024),
      badgeCount: 0,
    );

    await tester.tap(find.byKey(const ValueKey('nav-/timeline')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/timeline');
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('nav-/timeline')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('nav-/collection')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
  });

  testWidgets('compact Friends selection keeps the shell overflow-free', (
    tester,
  ) async {
    final router = await _pumpShell(
      tester,
      size: const Size(390, 844),
      badgeCount: 0,
    );

    router.go('/friends');
    await tester.pumpAndSettle();

    expect(_selectedFlag(tester, '/friends'), Tristate.isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge destinations keep a visible keyboard focus ring', (
    tester,
  ) async {
    await _pumpShell(tester, size: const Size(390, 844), badgeCount: 0);

    for (final route in <String>['/collection', '/friends']) {
      await _focusRoute(tester, route);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('focus-ring-$route')),
          matching: find.byWidgetPredicate((widget) {
            if (widget is! DecoratedBox) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.border?.top.width == AppFocus.ringWidth &&
                decoration.border?.top.color == AppFocus.color;
          }),
        ),
        findsOneWidget,
      );
    }
  });

  for (final size in <Size>[const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets(
      'all shell controls at ${size.width.toInt()} expose working semantic taps',
      (tester) async {
        final router = await _pumpShell(tester, size: size, badgeCount: 2);

        for (final route in <String>[
          '/timeline',
          '/places',
          '/friends',
          '/collection',
        ]) {
          await _performSemanticTap(tester, find.byKey(ValueKey('nav-$route')));
          expect(router.routeInformationProvider.value.uri.path, route);
        }

        await _performSemanticTap(
          tester,
          find.byKey(const ValueKey('melt-pin')),
        );
        expect(find.text('CHECK-IN'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();

        await _performSemanticTap(
          tester,
          find.byKey(const ValueKey('profile-avatar')),
        );
        expect(find.text('PROFILE'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await _performSemanticTap(
          tester,
          find.byKey(const ValueKey('settings-gear-shell')),
        );
        expect(find.text('SETTINGS'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/collection');
      },
    );
  }

  testWidgets('wide edge focus outlines stay entirely inside the viewport', (
    tester,
  ) async {
    const size = Size(1024, 900);
    await _pumpShell(tester, size: size, badgeCount: 0);

    for (final route in <String>['/collection', '/friends']) {
      await _focusRoute(tester, route);
      final outline = _focusOutline(route);
      expect(outline, findsOneWidget);
      final rect = tester.getRect(outline);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    }
  });

  testWidgets('narrow shell constraints override a wider ambient MediaQuery', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: const Size(1440, 1000),
      shellWidth: 390,
      badgeCount: 0,
    );

    expect(find.byType(EditorialTopNavigation), findsNothing);
    expect(find.byType(FloatingBottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation honors a nonzero safe-area inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    const size = Size(390, 844);
    await _pumpShell(tester, size: size, badgeCount: 0);

    final surfaceBottom = tester
        .getBottomRight(find.byKey(const ValueKey('bottom-nav-surface')))
        .dy;
    expect(surfaceBottom, lessThanOrEqualTo(size.height - 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard inset keeps content and navigation usable', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    const size = Size(390, 844);
    final router = await _pumpShell(tester, size: size, badgeCount: 0);

    expect(find.text('/collection'), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('bottom-nav-surface')))
          .dy,
      lessThanOrEqualTo(size.height - 300),
    );
    await _performSemanticTap(
      tester,
      find.byKey(const ValueKey('nav-/timeline')),
    );
    expect(router.routeInformationProvider.value.uri.path, '/timeline');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _performSemanticTap(WidgetTester tester, Finder control) async {
  final node = tester.getSemantics(control);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

Finder _focusOutline(String route) => find.descendant(
  of: find.byKey(ValueKey('focus-ring-$route')),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration &&
        decoration.border?.top.width == AppFocus.ringWidth &&
        decoration.border?.top.color == AppFocus.color;
  }),
);

Future<void> _focusRoute(WidgetTester tester, String route) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final context = FocusManager.instance.primaryFocus?.context;
    var found = false;
    context?.visitAncestorElements((element) {
      if (element.widget.key == ValueKey('nav-$route')) {
        found = true;
        return false;
      }
      return true;
    });
    if (found) return;
  }
  fail('Unable to focus $route');
}

Tristate _selectedFlag(WidgetTester tester, String route) => tester
    .getSemantics(find.byKey(ValueKey('nav-$route')))
    .flagsCollection
    .isSelected;

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required int badgeCount,
  double? shellWidth,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late final GoRouter router;
  Widget destination(BuildContext context, GoRouterState state) {
    final shell = AuthenticatedShell(
      location: state.uri.path,
      child: Center(child: Text(state.uri.path)),
    );
    if (shellWidth == null) return shell;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: shellWidth, height: size.height, child: shell),
    );
  }

  router = GoRouter(
    initialLocation: '/collection',
    routes: <RouteBase>[
      for (final path in <String>[
        '/collection',
        '/timeline',
        '/places',
        '/friends',
      ])
        GoRoute(path: path, builder: destination),
      GoRoute(
        path: '/check-in',
        builder: (_, _) => const Scaffold(body: Text('CHECK-IN')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendsBadgeCountProvider.overrideWithValue(badgeCount),
        ownProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
