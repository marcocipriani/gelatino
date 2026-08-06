import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/router_auth_provider.dart';
import 'package:gelatino/router.dart';
import 'package:gelatino/screens/login_screen.dart';
import 'package:gelatino/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

void main() {
  final sizes = <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 900),
    const Size(1440, 1000),
  ];

  for (final size in sizes) {
    testWidgets(
      'A1 Access at ${size.width.toInt()} uses the correct responsive composition',
      (tester) async {
        await _pumpLogin(tester, size: size);

        final brand = find.byKey(const ValueKey('access-brand-panel'));
        final artwork = find.byKey(const ValueKey('access-artwork-panel'));
        final action = find.byKey(const ValueKey('access-google-action'));
        expect(brand, findsOneWidget);
        expect(artwork, findsOneWidget);
        expect(find.byKey(const ValueKey('access-gelato-art')), findsOneWidget);
        expect(action, findsOneWidget);
        expect(find.text(AppStrings.loginButton), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));

        final brandRect = tester.getRect(brand);
        final artRect = tester.getRect(artwork);
        if (size.width >= AppBreakpoints.wideMin) {
          expect(brandRect.left, 0);
          expect(artRect.right, closeTo(size.width, 0.01));
          expect(brandRect.right, closeTo(artRect.left, 0.01));
          expect(brandRect.width / size.width, closeTo(0.48, 0.01));
          expect(artRect.width / size.width, closeTo(0.52, 0.01));
          expect(brandRect.top, closeTo(artRect.top, 0.01));
          expect(brandRect.bottom, closeTo(artRect.bottom, 0.01));
          expect(
            tester
                .getSize(find.byKey(const ValueKey('access-brand-content')))
                .width,
            lessThanOrEqualTo(520),
          );
          expect(
            tester
                .getRect(find.byKey(const ValueKey('access-brand-content')))
                .center
                .dy,
            closeTo(brandRect.center.dy, 0.01),
          );
        } else {
          expect(brandRect.top, lessThan(artRect.top));
          expect(artRect.width / artRect.height, closeTo(4 / 3, 0.01));
          final expectedPadding = size.width < 600 ? 16.0 : 24.0;
          expect(
            tester
                .getRect(find.byKey(const ValueKey('access-brand-content')))
                .left,
            closeTo(expectedPadding, 0.01),
          );
          expect(artRect.left, closeTo(expectedPadding, 0.01));
          expect(artRect.right, closeTo(size.width - expectedPadding, 0.01));
          expect(find.byType(SingleChildScrollView), findsOneWidget);
        }

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Google action is keyboard reachable, single-flight and stable while loading',
    (tester) async {
      final session = _FakeRouterAuthSession();
      await _pumpLogin(tester, session: session);

      final action = find.byKey(const ValueKey('access-google-action'));
      final idleSize = tester.getSize(action);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(session.signInCalls, 1);

      await tester.tap(action);
      await tester.pump();
      expect(session.signInCalls, 1);
      expect(tester.getSize(action), idleSize);
      expect(find.byKey(const ValueKey('access-progress')), findsOneWidget);
      final progress = tester.getSemantics(
        find.byKey(const ValueKey('access-progress')),
      );
      expect(progress.label, 'Accesso in corso');
      expect(
        tester.getSemantics(action).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    },
  );

  testWidgets('wide Access scrolls at 1024x600 with 200% text', (tester) async {
    await _pumpLogin(
      tester,
      size: const Size(1024, 600),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    final scrollable = find.byKey(const ValueKey('access-wide-brand-scroll'));
    expect(scrollable, findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final action = find.byKey(const ValueKey('access-google-action'));
    await tester.scrollUntilVisible(
      action,
      240,
      scrollable: find.descendant(
        of: scrollable,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Access keeps a single outer scroll viewport', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      size: const Size(390, 600),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('access-wide-brand-scroll')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Access removes state animation when motion is disabled', (
    tester,
  ) async {
    await _pumpLogin(tester, disableAnimations: true);

    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  testWidgets('dark Access renders the inline error with AA contrast', (
    tester,
  ) async {
    final session = _FakeRouterAuthSession();
    await _pumpLogin(tester, session: session, themeMode: ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('access-google-action')));
    await tester.pump();
    session.failNext(Exception('private Firebase detail'));
    await tester.pump();

    final errorText = tester.widget<Text>(
      find.text('Accesso non riuscito. Riprova.'),
    );
    final errorColor = errorText.style!.color!;
    expect(
      _contrastRatio(errorColor, AppTheme.darkTheme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(errorColor, AppTheme.darkTheme.colorScheme.error);
  });

  testWidgets('auth failure is sanitized inline and the same action retries', (
    tester,
  ) async {
    final session = _FakeRouterAuthSession();
    final router = await _pumpLogin(
      tester,
      session: session,
      initialLocation: '/login?redirect=%2Fjoin%3Fby%3Dbob',
    );
    final action = find.byKey(const ValueKey('access-google-action'));

    await tester.tap(action);
    await tester.pump();
    session.failNext(
      Exception('[firebase_auth/account-exists] secret@example.test'),
    );
    await tester.pump();

    const safeMessage = 'Accesso non riuscito. Riprova.';
    expect(find.text(safeMessage), findsOneWidget);
    expect(find.textContaining('firebase_auth'), findsNothing);
    expect(find.textContaining('secret@example.test'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/login?redirect=%2Fjoin%3Fby%3Dbob',
    );
    final errorSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('access-auth-error')),
    );
    expect(errorSemantics.properties.liveRegion, isTrue);

    await tester.tap(action);
    await tester.pump();
    expect(session.signInCalls, 2);
    session.succeedNext('alice');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/join?by=bob',
    );
    expect(find.text('JOIN TARGET: bob'), findsOneWidget);
  });

  testWidgets('hostile redirect falls back to Collection after success', (
    tester,
  ) async {
    final session = _FakeRouterAuthSession();
    final router = await _pumpLogin(
      tester,
      session: session,
      initialLocation: '/login?redirect=https%3A%2F%2Fevil.example%2Fsteal',
    );

    await tester.tap(find.byKey(const ValueKey('access-google-action')));
    await tester.pump();
    session.succeedNext('alice');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/collection');
    expect(find.text('COLLECTION TARGET'), findsOneWidget);
  });

  for (final refreshBeforeCompletion in <bool>[true, false]) {
    testWidgets('actual router keeps invite when auth refresh is '
        '${refreshBeforeCompletion ? 'before' : 'during'} sign-in completion', (
      tester,
    ) async {
      final session = _FakeRouterAuthSession();
      final router = await _pumpActualAppRouter(tester, session);
      router.go('/join?by=bob');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/login?redirect=%2Fjoin%3Fby%3Dbob',
      );

      await tester.tap(find.byKey(const ValueKey('access-google-action')));
      await tester.pump();
      expect(session.signInCalls, 1);

      if (refreshBeforeCompletion) {
        session.publishAuthenticatedUid('alice');
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/join?by=bob',
        );
        session.completeNext();
      } else {
        session.succeedNext('alice');
      }
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/join?by=bob',
      );
      expect(find.text('Profilo non trovato.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Access exposes one primary action and announced heading states',
    (tester) async {
      await _pumpLogin(tester);

      final heading = tester.getSemantics(
        find.byKey(const ValueKey('access-title')),
      );
      expect(heading.label, 'Il tuo diario del gelato');
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton &&
              widget.key == const ValueKey('access-google-action'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    },
  );

  test('Access keeps auth and artwork local behind static boundaries', () {
    final login = File('lib/screens/login_screen.dart').readAsStringSync();
    final photoPanel = File(
      'lib/widgets/access_photo_panel.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final artworkFile = File('assets/images/access-gelato-art.svg');

    expect(login, contains('routerAuthSessionProvider'));
    expect(login, contains('safeInternalRedirect'));
    expect(login, contains('AccessPhotoPanel'));
    expect(photoPanel, contains('assets/images/access-gelato-art.svg'));
    expect(login, isNot(contains('FirebaseAuth.instance')));
    expect(login, isNot(contains('GoogleSignIn.instance')));
    expect(login, isNot(contains('Image.network')));
    expect(login, isNot(contains('CachedNetworkImage')));
    expect(photoPanel, isNot(contains('Image.network')));
    expect(photoPanel, isNot(contains('CachedNetworkImage')));
    expect(pubspec, contains('assets/images/'));
    expect(artworkFile.existsSync(), isTrue);

    final artwork = artworkFile.readAsStringSync().toLowerCase();
    expect(artwork, isNot(contains('<text')));
    expect(artwork, isNot(contains('href=')));
  });
}

Future<GoRouter> _pumpLogin(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  _FakeRouterAuthSession? session,
  String initialLocation = '/login',
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final authSession = session ?? _FakeRouterAuthSession();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/collection',
        builder: (_, _) => const Scaffold(body: Text('COLLECTION TARGET')),
      ),
      GoRoute(
        path: '/join',
        builder: (_, state) => Scaffold(
          body: Text('JOIN TARGET: ${state.uri.queryParameters['by']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [routerAuthSessionProvider.overrideWithValue(authSession)],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<GoRouter> _pumpActualAppRouter(
  WidgetTester tester,
  _FakeRouterAuthSession session,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      routerAuthSessionProvider.overrideWithValue(session),
      currentUidProvider.overrideWithValue('alice'),
      publicProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

final class _FakeRouterAuthSession extends ChangeNotifier
    implements RouterAuthSession {
  final Queue<Completer<void>> _attempts = Queue<Completer<void>>();
  String? _uid;
  var signInCalls = 0;

  @override
  String? get uid => _uid;

  @override
  Future<void> signInWithGoogle() {
    signInCalls += 1;
    final attempt = Completer<void>();
    _attempts.add(attempt);
    return attempt.future;
  }

  void failNext(Object error) {
    _attempts.removeFirst().completeError(error);
  }

  void succeedNext(String uid) {
    _uid = uid;
    _attempts.removeFirst().complete();
    notifyListeners();
  }

  void publishAuthenticatedUid(String uid) {
    _uid = uid;
    notifyListeners();
  }

  void completeNext() {
    _attempts.removeFirst().complete();
  }
}
