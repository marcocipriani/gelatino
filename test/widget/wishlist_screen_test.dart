import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/router_auth_provider.dart';
import 'package:gelatino/router.dart';

void main() {
  testWidgets('legacy /wishlist resolves to Collection in the real router', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = _FakeRouterAuthSession('alice');
    final container = ProviderContainer(
      overrides: [
        routerAuthSessionProvider.overrideWithValue(session),
        currentUidProvider.overrideWithValue('alice'),
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
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go('/wishlist');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/collection');
    expect(find.text('La tua collezione'), findsOneWidget);
  });

  test('router has one Collection runtime implementation', () {
    final router = File('lib/router.dart').readAsStringSync();

    expect(router, contains("path: '/wishlist'"));
    expect(router, contains("redirect: (context, state) => '/collection'"));
    expect(router, isNot(contains('WishlistScreen')));
    expect(router, isNot(contains("screens/wishlist_screen.dart")));
    expect(File('lib/screens/wishlist_screen.dart').existsSync(), isFalse);
  });
}

final class _FakeRouterAuthSession extends ChangeNotifier
    implements RouterAuthSession {
  _FakeRouterAuthSession(this._uid);

  final String? _uid;

  @override
  String? get uid => _uid;

  @override
  Future<void> signInWithGoogle() async {}
}
