import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/motion.dart';
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
        // Every tab pads itself; padding here too doubled the gutters.
        builder: (context, state, child) =>
            MainScreen(location: state.uri.path, fullBleed: true, child: child),
        routes: [
          GoRoute(
            path: '/collection',
            pageBuilder: (context, state) =>
                _tabPage(state, const CollectionScreen()),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (context, state) =>
                _tabPage(state, const TimelineScreen()),
          ),
          GoRoute(
            path: '/places',
            pageBuilder: (context, state) => _tabPage(state, const PlacesTab()),
          ),
          GoRoute(
            path: '/friends',
            pageBuilder: (context, state) =>
                _tabPage(state, const FriendsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/check-in',
        pageBuilder: (context, state) {
          final placeId = state.uri.queryParameters['placeId'];
          final prefillFriendId = state.uri.queryParameters['prefillFriendId'];
          return _sheetPage(
            state,
            CheckInScreen(placeId: placeId, prefillFriendId: prefillFriendId),
          );
        },
      ),
      GoRoute(path: '/wishlist', redirect: (context, state) => '/collection'),
      GoRoute(
        path: '/favorite-flavors',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const FavoriteFlavorsScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: ProfileScreen(userId: state.uri.queryParameters['userId']),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/place/:id',
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: PlaceDetailScreen(placeId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Tabs are siblings, so they fade through rather than push. The page paints
/// its own canvas because the outgoing tab stays put until this one lands.
CustomTransitionPage<void> _tabPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.standard,
      reverseTransitionDuration: AppMotion.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final page = ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
        final eased = animation.drive(CurveTween(curve: AppMotion.enter));
        return FadeTransition(
          opacity: AppMotion.reduced(context)
              ? kAlwaysCompleteAnimation
              : eased,
          child: SlideTransition(
            position: AppMotion.reduced(context)
                ? const AlwaysStoppedAnimation(Offset.zero)
                : eased.drive(
                    Tween(begin: const Offset(0, 0.012), end: Offset.zero),
                  ),
            child: page,
          ),
        );
      },
    );

/// A modal task: rises over the screen it was opened from, which stays painted.
CustomTransitionPage<void> _sheetPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: AppMotion.emphasized,
      reverseTransitionDuration: AppMotion.standard,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          AppMotion.reduced(context)
          ? FadeTransition(opacity: animation, child: child)
          : SlideTransition(
              position: animation.drive(
                Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: AppMotion.glide)),
              ),
              child: child,
            ),
    );
