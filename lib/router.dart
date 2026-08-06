import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/router_auth_provider.dart';
import 'screens/check_in_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/favorite_flavors_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/place_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/places_tab.dart';
import 'screens/timeline_screen.dart';

export 'utils/auth_redirect.dart' show authRedirectFor, safeInternalRedirect;
import 'utils/auth_redirect.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(routerAuthSessionProvider);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) =>
        authRedirectFor(uid: session.uid, location: state.uri),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/join',
        builder: (context, state) =>
            InviteScreen(userId: state.uri.queryParameters['by']),
      ),
      GoRoute(
        path: '/invite/:uid',
        redirect: (context, state) => Uri(
          path: '/join',
          queryParameters: <String, String>{
            'by': state.pathParameters['uid'] ?? '',
          },
        ).toString(),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/collection'),
      ShellRoute(
        builder: (context, state, child) => MainScreen(
          location: state.uri.path,
          fullBleed:
              state.uri.path == '/places' || state.uri.path == '/timeline',
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/collection',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CollectionScreen(),
            ),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const TimelineScreen(),
            ),
          ),
          GoRoute(
            path: '/places',
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const PlacesTab()),
          ),
          GoRoute(
            path: '/friends',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const FriendsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/check-in',
        pageBuilder: (context, state) {
          final placeId = state.uri.queryParameters['placeId'];
          final prefillFriendId = state.uri.queryParameters['prefillFriendId'];
          return buildPageWithTransition(
            state: state,
            child: CheckInScreen(
              placeId: placeId,
              prefillFriendId: prefillFriendId,
            ),
            isSlideUp: true,
            opaque: false,
          );
        },
      ),
      GoRoute(path: '/wishlist', redirect: (context, state) => '/collection'),
      GoRoute(
        path: '/favorite-flavors',
        pageBuilder: (context, state) => buildPageWithTransition(
          state: state,
          child: const FavoriteFlavorsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => buildPageWithTransition(
          state: state,
          child: ProfileScreen(userId: state.uri.queryParameters['userId']),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => buildPageWithTransition(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/place/:id',
        pageBuilder: (context, state) => buildPageWithTransition(
          state: state,
          child: PlaceDetailScreen(placeId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

Page<dynamic> buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
  bool isSlideUp = false,
  bool opaque = true,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    opaque: opaque,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (isSlideUp) {
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        );
      }
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0.05, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      );
    },
  );
}
