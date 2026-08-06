import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/screens/friends_screen.dart';
import 'package:gelatino/widgets/authenticated_shell.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Friends badge destination changes the location to /friends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/collection',
      routes: [
        for (final path in <String>['/collection', '/timeline', '/places'])
          GoRoute(
            path: path,
            builder: (_, state) => AuthenticatedShell(
              location: state.uri.path,
              child: Text(state.uri.path),
            ),
          ),
        GoRoute(
          path: '/friends',
          builder: (_, state) => AuthenticatedShell(
            location: state.uri.path,
            child: const Text('FRIENDS ROUTE'),
          ),
        ),
        GoRoute(path: '/check-in', builder: (_, _) => const Text('CHECK-IN')),
        GoRoute(path: '/profile', builder: (_, _) => const Text('PROFILE')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsBadgeCountProvider.overrideWithValue(2),
          savedPlacesProvider.overrideWithValue(
            const AsyncData<List<Place>>(<Place>[]),
          ),
          ownProfileProvider.overrideWith(
            (ref) => Stream<UserProfile?>.value(null),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amici'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/friends');
    expect(find.text('FRIENDS ROUTE'), findsOneWidget);
  });

  test('external invite URI preserves reserved UID characters', () {
    for (final uid in <String>['alice&bob', 'alice#bob', 'alice%bob']) {
      final uri = buildExternalInviteUri(uid);

      expect(uri.scheme, 'https');
      expect(uri.host, 'gelatino.web.app');
      expect(uri.path, '/join');
      expect(uri.queryParameters, <String, String>{'by': uid});
      expect(Uri.parse(uri.toString()).queryParameters['by'], uid);
    }
  });
}
