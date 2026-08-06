import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/router_auth_provider.dart';
import 'package:gelatino/router.dart';

void main() {
  test(
    'settings is a top-level auxiliary route, never a primary shell tab',
    () {
      final source = File('lib/router.dart').readAsStringSync();
      expect(source, contains("path: '/settings'"));
      final shellStart = source.indexOf('ShellRoute(');
      final shellEnd = source.indexOf("path: '/check-in'");
      expect(shellStart, greaterThanOrEqualTo(0));
      expect(shellEnd, greaterThan(shellStart));
      expect(
        source.substring(shellStart, shellEnd),
        isNot(contains("path: '/settings'")),
      );
    },
  );

  test('guest invite preserves the exact internal location through login', () {
    expect(
      authRedirectFor(uid: null, location: Uri.parse('/join?by=bob')),
      '/login?redirect=%2Fjoin%3Fby%3Dbob',
    );
  });

  test('authenticated login returns to a validated invite location', () {
    expect(
      authRedirectFor(
        uid: 'alice',
        location: Uri.parse('/login?redirect=%2Fjoin%3Fby%3Dbob'),
      ),
      '/join?by=bob',
    );
  });

  test('hostile and malformed login redirects fall back to root', () {
    for (final value in <String>[
      'https://evil.example/path',
      '//evil.example/path',
      r'/safe\evil',
      '/safe\npath',
      '/safe%5Cevil',
      '/safe%0Apath',
      '/%2F/evil',
      'relative/path',
      '%',
      '/login',
    ]) {
      expect(safeInternalRedirect(value), isNull, reason: value);
    }
    expect(safeInternalRedirect('/join?by=bob'), '/join?by=bob');
  });

  test('login and invite are the only unauthenticated routing exceptions', () {
    expect(authRedirectFor(uid: null, location: Uri.parse('/login')), isNull);
    expect(
      authRedirectFor(uid: null, location: Uri.parse('/profile')),
      '/login?redirect=%2Fprofile',
    );
    expect(
      authRedirectFor(uid: null, location: Uri.parse('/settings')),
      '/login?redirect=%2Fsettings',
    );
  });

  testWidgets('injected auth refresh returns guest invite without a loop', (
    tester,
  ) async {
    final session = _FakeRouterAuthSession();
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/join?by=bob');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/login?redirect=%2Fjoin%3Fby%3Dbob',
    );

    session.authenticate('alice');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/join?by=bob',
    );
    expect(find.text('Profilo non trovato.'), findsOneWidget);

    session.notifyAuthRefresh();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/join?by=bob',
    );
  });
}

final class _FakeRouterAuthSession extends ChangeNotifier
    implements RouterAuthSession {
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
