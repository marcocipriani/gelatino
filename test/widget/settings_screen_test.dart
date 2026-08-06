import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/firebase/firebase_providers.dart';
import 'package:gelatino/models/user_profile.dart';
import 'package:gelatino/models/user_settings.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/providers/theme_provider.dart';
import 'package:gelatino/repositories/profile_repository.dart';
import 'package:gelatino/screens/settings_screen.dart';
import 'package:gelatino/widgets/edit_profile_dialog.dart';
import 'package:go_router/go_router.dart';

final _settingsUidProvider = NotifierProvider<_SettingsUid, String?>(
  _SettingsUid.new,
);

void main() {
  testWidgets('settings uses page below wide and bounded drawer on wide', (
    tester,
  ) async {
    for (final testCase in <({double width, String layout})>[
      (width: 390, layout: 'compact'),
      (width: 768, layout: 'medium'),
      (width: 1024, layout: 'wide'),
      (width: 1440, layout: 'wide'),
    ]) {
      tester.view.physicalSize = Size(testCase.width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_settingsHarness(textScale: 2));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('settings-${testCase.layout}')),
        findsOneWidget,
      );
      expect(find.text('Impostazioni'), findsOneWidget);
      if (testCase.layout == 'wide') {
        final drawer = find.byKey(const ValueKey('settings-wide-drawer'));
        expect(drawer, findsOneWidget);
        final width = tester.getSize(drawer).width;
        expect(width, inInclusiveRange(380, 440));
        expect(
          find.byKey(const ValueKey('settings-wide-background')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ExcludeSemantics>(
                find.byKey(const ValueKey('settings-wide-background')),
              )
              .excluding,
          isTrue,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('settings-wide-background')),
            matching: find.byType(IgnorePointer),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings-wide-barrier')),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(const ValueKey('settings-wide-drawer')),
          findsNothing,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('settings-back'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('settings honors narrow constraints inside a wide MediaQuery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(_settingsHarness(contentWidth: 390));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-compact')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-wide-drawer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings loading null and error are distinct and sanitized', (
    tester,
  ) async {
    for (final testCase in <({AsyncValue<UserSettings?> value, String text})>[
      (
        value: const AsyncLoading<UserSettings?>(),
        text: 'Caricamento impostazioni',
      ),
      (
        value: const AsyncData<UserSettings?>(null),
        text: 'Impostazioni non trovate',
      ),
      (
        value: AsyncError<UserSettings?>(
          StateError('raw settings backend secret'),
          StackTrace.current,
        ),
        text: 'Impostazioni non disponibili',
      ),
    ]) {
      await tester.pumpWidget(
        _settingsHarness(settings: testCase.value, key: UniqueKey()),
      );
      await tester.pump();

      expect(find.text(testCase.text), findsOneWidget);
      expect(find.textContaining('backend secret'), findsNothing);
    }
  });

  testWidgets('settings provider error exposes a real retry', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      _settingsHarness(
        settingsFactory: () {
          reads++;
          return Stream<UserSettings?>.error(
            StateError('raw settings backend'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(reads, 1);
    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('settings-retry-load')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.textContaining('raw settings backend'), findsNothing);
  });

  testWidgets('settings renders only supported real controls', (tester) async {
    await tester.pumpWidget(_settingsHarness());
    await tester.pumpAndSettle();

    for (final key in <String>[
      'settings-edit-profile',
      'settings-favorite-flavors',
      'settings-saved-collection',
      'settings-theme',
      'settings-default-view',
      'settings-private-profile',
      'settings-logout',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.textContaining('non comparire nelle ricerche'), findsOneWidget);
    for (final unsupported in <String>[
      'Esporta dati',
      'Elimina account',
      'Notifiche',
      'Movimento ridotto',
    ]) {
      expect(find.textContaining(unsupported), findsNothing);
    }
  });

  testWidgets('profile settings actions navigate to their real destinations', (
    tester,
  ) async {
    final router = await _pumpSettingsRouter(
      tester,
      size: const Size(390, 844),
      initialLocation: '/settings',
    );

    final edit = tester
        .widget<ListTile>(find.byKey(const ValueKey('settings-edit-profile')))
        .onTap!;
    edit();
    edit();
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileDialog), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    final favorite = tester
        .widget<ListTile>(
          find.byKey(const ValueKey('settings-favorite-flavors')),
        )
        .onTap!;
    favorite();
    favorite();
    await tester.pumpAndSettle();
    expect(find.text('FAVORITE FLAVORS'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');

    final saved = tester
        .widget<ListTile>(
          find.byKey(const ValueKey('settings-saved-collection')),
        )
        .onTap!;
    saved();
    saved();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/collection');
    expect(find.text('COLLECTION'), findsOneWidget);
  });

  testWidgets('edit profile stays bounded until own profile is valid', (
    tester,
  ) async {
    for (final profile in <AsyncValue<UserProfile?>>[
      const AsyncLoading<UserProfile?>(),
      const AsyncData<UserProfile?>(null),
      AsyncError<UserProfile?>(
        StateError('raw profile backend secret'),
        StackTrace.current,
      ),
    ]) {
      await tester.pumpWidget(
        _settingsHarness(profile: profile, key: UniqueKey()),
      );
      await tester.pump();

      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('settings-edit-profile')),
            )
            .onTap,
        isNull,
      );
      expect(find.textContaining('backend secret'), findsNothing);
      expect(find.byType(EditProfileDialog), findsNothing);
    }
  });

  testWidgets('logout is single-flight and exact-once', (tester) async {
    final auth = _ActionAuth()..gate = Completer<void>();
    await tester.pumpWidget(_settingsHarness(auth: auth));
    await tester.pumpAndSettle();

    final logout = tester.widget<FilledButton>(
      find.byKey(const ValueKey('settings-logout')),
    );
    logout.onPressed!();
    logout.onPressed!();
    await tester.pump();

    expect(auth.signOutCalls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('settings-logout')))
          .onPressed,
      isNull,
    );
    auth.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('logout failure is sanitized and retries the exact action', (
    tester,
  ) async {
    final auth = _ActionAuth()..failuresRemaining = 1;
    await tester.pumpWidget(_settingsHarness(auth: auth));
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.byKey(const ValueKey('settings-logout')))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.textContaining('raw logout backend secret'), findsNothing);
    expect(find.text('Uscita non riuscita. Riprova.'), findsOneWidget);
    expect(find.text('Modifica non salvata. Riprova.'), findsNothing);
    final retry = find.byKey(const ValueKey('settings-retry-logout'));
    expect(retry, findsOneWidget);
    tester.widget<TextButton>(retry).onPressed!();
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 2);
    expect(retry, findsNothing);
  });

  testWidgets('successful logout remains terminal while auth is still stale', (
    tester,
  ) async {
    final auth = _ActionAuth();
    await tester.pumpWidget(_settingsHarness(auth: auth));
    await tester.pumpAndSettle();

    final logout = tester
        .widget<FilledButton>(find.byKey(const ValueKey('settings-logout')))
        .onPressed!;
    logout();
    await tester.pumpAndSettle();
    logout();
    await tester.pump();

    expect(auth.signOutCalls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('settings-logout')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('stale UID logout failure cannot leak into the next account', (
    tester,
  ) async {
    final auth = _ActionAuth()
      ..gate = Completer<void>()
      ..failuresRemaining = 1;
    await tester.pumpWidget(_settingsHarness(auth: auth, dynamicUid: true));
    await tester.pumpAndSettle();

    tester
        .widget<FilledButton>(find.byKey(const ValueKey('settings-logout')))
        .onPressed!();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    container.read(_settingsUidProvider.notifier).set('zoe');
    await tester.pump();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-retry-logout')), findsNothing);
    expect(find.textContaining('Modifica non salvata'), findsNothing);
  });

  testWidgets('default view and privacy are single-flight per field', (
    tester,
  ) async {
    final repository = _ActionProfileRepository()
      ..defaultGate = Completer<void>()
      ..privacyGate = Completer<void>();
    await tester.pumpWidget(_settingsHarness(repository: repository));
    await tester.pumpAndSettle();

    final defaultView = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('settings-default-view')),
    );
    defaultView.onChanged!('map');
    defaultView.onChanged!('map');
    final privacy = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('settings-private-profile')),
    );
    privacy.onChanged!(false);
    privacy.onChanged!(false);
    await tester.pump();

    expect(repository.defaultCalls, <(String, String)>[('alice', 'map')]);
    expect(repository.privacyCalls, <(String, bool)>[('alice', false)]);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('settings-default-view')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('settings-private-profile')),
          )
          .onChanged,
      isNull,
    );

    repository.defaultGate!.complete();
    repository.privacyGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('repository settings fields expose durable exact retry', (
    tester,
  ) async {
    final repository = _ActionProfileRepository()
      ..defaultFailuresRemaining = 1
      ..privacyFailuresRemaining = 1;
    await tester.pumpWidget(_settingsHarness(repository: repository));
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('settings-default-view')),
        )
        .onChanged!('map');
    tester
        .widget<SwitchListTile>(
          find.byKey(const ValueKey('settings-private-profile')),
        )
        .onChanged!(false);
    await tester.pumpAndSettle();

    expect(find.textContaining('raw field backend'), findsNothing);
    for (final field in <String>['default-view', 'privacy']) {
      final retry = find.byKey(ValueKey('settings-retry-$field'));
      expect(retry, findsOneWidget, reason: field);
      tester.widget<TextButton>(retry).onPressed!();
    }
    await tester.pumpAndSettle();

    expect(repository.defaultCalls, <(String, String)>[
      ('alice', 'map'),
      ('alice', 'map'),
    ]);
    expect(repository.privacyCalls, <(String, bool)>[
      ('alice', false),
      ('alice', false),
    ]);
    expect(
      find.byKey(const ValueKey('settings-retry-default-view')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('settings-retry-privacy')), findsNothing);
  });

  testWidgets(
    'real theme notifier surfaces first failure and exact retry without duplicate intent',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      final preferences = _RealThemePreferences('system')
        ..failuresRemaining = 1;
      final scheduler = _SettingsThemeRetryScheduler();
      final repository = _ActionProfileRepository();
      await tester.pumpWidget(
        _settingsHarness(
          repository: repository,
          themePreferences: preferences,
          themeRetryScheduler: scheduler,
        ),
      );
      await tester.pumpAndSettle();

      final select = tester
          .widget<DropdownButton<ThemeMode>>(
            find.byKey(const ValueKey('settings-theme')),
          )
          .onChanged!;
      select(ThemeMode.dark);
      select(ThemeMode.dark);
      expect(await scheduler.firstScheduled.future, 1);
      await tester.pump();
      FlutterError.onError = previous;

      expect(preferences.writeAttempts, <String>['dark']);
      expect(
        find.byKey(const ValueKey('settings-retry-theme')),
        findsOneWidget,
      );
      expect(find.textContaining('raw theme backend secret'), findsNothing);

      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('settings-retry-theme')),
          )
          .onPressed!();
      scheduler.releaseNext();
      await tester.pumpAndSettle();

      expect(preferences.writeAttempts, <String>['dark', 'dark']);
      expect(repository.themeCalls, <(String, String)>[('alice', 'dark')]);
      expect(find.byKey(const ValueKey('settings-retry-theme')), findsNothing);
      expect(errors, hasLength(1));
    },
  );

  testWidgets('real theme feedback ignores a stale UID completion', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final preferences = _RealThemePreferences('system')
      ..gate = Completer<void>()
      ..failuresRemaining = 1;
    await tester.pumpWidget(
      _settingsHarness(themePreferences: preferences, dynamicUid: true),
    );
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButton<ThemeMode>>(
          find.byKey(const ValueKey('settings-theme')),
        )
        .onChanged!(ThemeMode.dark);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    container.read(_settingsUidProvider.notifier).set('zoe');
    container.read(themeModeProvider.notifier).synchronizeIdentity('zoe');
    await tester.pump();
    preferences.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-retry-theme')), findsNothing);
    expect(find.textContaining('Modifica non salvata'), findsNothing);
    expect(errors, hasLength(1));
  });

  testWidgets('real theme newer intent clears old failure and retry', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    final preferences = _RealThemePreferences('system')..failuresRemaining = 1;
    final scheduler = _SettingsThemeRetryScheduler();
    await tester.pumpWidget(
      _settingsHarness(
        themePreferences: preferences,
        themeRetryScheduler: scheduler,
      ),
    );
    await tester.pumpAndSettle();

    DropdownButton<ThemeMode> control() =>
        tester.widget<DropdownButton<ThemeMode>>(
          find.byKey(const ValueKey('settings-theme')),
        );
    control().onChanged!(ThemeMode.dark);
    expect(await scheduler.firstScheduled.future, 1);
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-retry-theme')), findsOneWidget);

    control().onChanged!(ThemeMode.light);
    await tester.pumpAndSettle();
    scheduler.releaseNext();
    await tester.pumpAndSettle();

    expect(preferences.writeAttempts, <String>['dark', 'light']);
    expect(control().value, ThemeMode.light);
    expect(find.byKey(const ValueKey('settings-retry-theme')), findsNothing);
    expect(errors, hasLength(1));
  });

  testWidgets('stale UID completions cannot expose settings failures', (
    tester,
  ) async {
    final repository = _ActionProfileRepository()
      ..defaultGate = Completer<void>()
      ..defaultFailuresRemaining = 1;
    await tester.pumpWidget(
      _settingsHarness(repository: repository, dynamicUid: true),
    );
    await tester.pumpAndSettle();

    tester
        .widget<DropdownButton<String>>(
          find.byKey(const ValueKey('settings-default-view')),
        )
        .onChanged!('map');
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    container.read(_settingsUidProvider.notifier).set('zoe');
    await tester.pump();
    repository.defaultGate!.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-retry-default-view')),
      findsNothing,
    );
    expect(find.textContaining('Modifica non salvata'), findsNothing);
  });

  testWidgets('newer field intent clears an older failure and retry', (
    tester,
  ) async {
    final repository = _ActionProfileRepository()..defaultFailuresRemaining = 1;
    await tester.pumpWidget(_settingsHarness(repository: repository));
    await tester.pumpAndSettle();

    DropdownButton<String> control() => tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('settings-default-view')),
    );
    control().onChanged!('map');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-retry-default-view')),
      findsOneWidget,
    );

    control().onChanged!('list');
    await tester.pumpAndSettle();

    expect(repository.defaultCalls, <(String, String)>[
      ('alice', 'map'),
      ('alice', 'list'),
    ]);
    expect(
      find.byKey(const ValueKey('settings-retry-default-view')),
      findsNothing,
    );
    expect(find.textContaining('Modifica non salvata'), findsNothing);
  });

  for (final dismissal in <String>['close', 'barrier', 'escape']) {
    testWidgets('wide drawer $dismissal returns to previous route', (
      tester,
    ) async {
      final router = await _pumpSettingsRouter(
        tester,
        size: const Size(1200, 900),
        initialLocation: '/collection',
      );
      unawaited(router.push('/settings'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-wide-drawer')),
        findsOneWidget,
      );

      switch (dismissal) {
        case 'close':
          tester
              .widget<IconButton>(find.byKey(const ValueKey('settings-close')))
              .onPressed!();
          break;
        case 'barrier':
          await tester.tapAt(const Offset(20, 450));
          break;
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          break;
      }
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/collection');
    });
  }

  for (final dismissal in <String>['close', 'barrier', 'escape']) {
    testWidgets('wide drawer $dismissal is latched against double dismissal', (
      tester,
    ) async {
      final router = await _pumpSettingsRouter(
        tester,
        size: const Size(1200, 900),
        initialLocation: '/collection',
      );
      unawaited(router.push('/settings'));
      await tester.pumpAndSettle();

      final VoidCallback dismiss = switch (dismissal) {
        'close' =>
          tester
              .widget<IconButton>(find.byKey(const ValueKey('settings-close')))
              .onPressed!,
        'barrier' =>
          tester
              .widget<ModalBarrier>(
                find.byKey(const ValueKey('settings-wide-barrier')),
              )
              .onDismiss!,
        _ =>
          tester
              .widget<CallbackShortcuts>(find.byType(CallbackShortcuts))
              .bindings
              .values
              .single,
      };
      dismiss();
      dismiss();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/collection');
    });
  }

  testWidgets('direct settings close falls back to owner profile', (
    tester,
  ) async {
    final router = await _pumpSettingsRouter(
      tester,
      size: const Size(390, 844),
      initialLocation: '/settings',
    );

    tester
        .widget<IconButton>(find.byKey(const ValueKey('settings-back')))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.text('OWNER PROFILE'), findsOneWidget);
  });
}

Widget _settingsHarness({
  double textScale = 1,
  Key? key,
  AsyncValue<UserSettings?> settings = const AsyncData<UserSettings?>(
    _settings,
  ),
  AsyncValue<UserProfile?>? profile,
  Stream<UserSettings?> Function()? settingsFactory,
  ProfileRepository? repository,
  ThemePreferences? themePreferences,
  ThemeRetryScheduler? themeRetryScheduler,
  FirebaseAuth? auth,
  bool dynamicUid = false,
  double? contentWidth,
}) {
  return ProviderScope(
    key: key,
    overrides: [
      if (dynamicUid)
        currentUidProvider.overrideWith(
          (ref) => ref.watch(_settingsUidProvider),
        )
      else
        currentUidProvider.overrideWithValue('alice'),
      ownProfileProvider.overrideWith((ref) {
        final value = profile ?? AsyncData<UserProfile?>(_profile);
        return switch (value) {
          AsyncData(:final value) => Stream<UserProfile?>.value(value),
          AsyncError(:final error, :final stackTrace) =>
            Stream<UserProfile?>.error(error, stackTrace),
          _ => const Stream<UserProfile?>.empty(),
        };
      }),
      ownSettingsProvider.overrideWith((ref) {
        if (settingsFactory case final factory?) return factory();
        return switch (settings) {
          AsyncData(:final value) => Stream<UserSettings?>.value(value),
          AsyncError(:final error, :final stackTrace) =>
            Stream<UserSettings?>.error(error, stackTrace),
          _ => const Stream<UserSettings?>.empty(),
        };
      }),
      profileRepositoryProvider.overrideWithValue(
        repository ?? _ActionProfileRepository(),
      ),
      themePreferencesProvider.overrideWithValue(
        themePreferences ?? _MemoryThemePreferences(),
      ),
      if (themeRetryScheduler != null)
        themeRetrySchedulerProvider.overrideWithValue(themeRetryScheduler),
      firebaseAuthProvider.overrideWithValue(auth ?? _ActionAuth()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: contentWidth == null
          ? const SettingsScreen()
          : Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: contentWidth,
                height: 1000,
                child: const SettingsScreen(),
              ),
            ),
    ),
  );
}

Future<GoRouter> _pumpSettingsRouter(
  WidgetTester tester, {
  required Size size,
  required String initialLocation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/collection',
        builder: (_, _) => const Scaffold(body: Text('COLLECTION')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('OWNER PROFILE')),
      ),
      GoRoute(
        path: '/favorite-flavors',
        builder: (_, _) => const Scaffold(body: Text('FAVORITE FLAVORS')),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('alice'),
        ownProfileProvider.overrideWith(
          (ref) => Stream<UserProfile?>.value(_profile),
        ),
        ownSettingsProvider.overrideWith(
          (ref) => Stream<UserSettings?>.value(_settings),
        ),
        profileRepositoryProvider.overrideWithValue(_ActionProfileRepository()),
        themePreferencesProvider.overrideWithValue(_MemoryThemePreferences()),
        firebaseAuthProvider.overrideWithValue(_ActionAuth()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

const _settings = UserSettings(
  themeMode: 'system',
  defaultCollectionView: 'list',
  reducedMotion: false,
  notificationsEnabled: true,
  profileVisibility: 'private',
  searchable: false,
);

final _profile = UserProfile(
  uid: 'alice',
  displayName: 'Alice Gelato con un nome molto lungo',
  points: 42,
);

final class _SettingsUid extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final class _ActionProfileRepository implements ProfileRepository {
  final List<(String, String)> defaultCalls = <(String, String)>[];
  final List<(String, bool)> privacyCalls = <(String, bool)>[];
  final List<(String, String)> themeCalls = <(String, String)>[];
  Completer<void>? defaultGate;
  Completer<void>? privacyGate;
  int defaultFailuresRemaining = 0;
  int privacyFailuresRemaining = 0;

  @override
  Future<void> updateDefaultCollectionView(String uid, String value) async {
    defaultCalls.add((uid, value));
    if (defaultGate case final gate?) await gate.future;
    if (defaultFailuresRemaining > 0) {
      defaultFailuresRemaining--;
      throw StateError('raw field backend default');
    }
  }

  @override
  Future<void> updatePrivacy(String uid, {required bool isPrivate}) async {
    privacyCalls.add((uid, isPrivate));
    if (privacyGate case final gate?) await gate.future;
    if (privacyFailuresRemaining > 0) {
      privacyFailuresRemaining--;
      throw StateError('raw field backend privacy');
    }
  }

  @override
  Future<void> updateThemeMode(String uid, String value) async {
    themeCalls.add((uid, value));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemoryThemePreferences implements ThemePreferences {
  @override
  String? readThemeMode() => 'system';

  @override
  Future<void> writeThemeMode(String value) async {}
}

final class _RealThemePreferences implements ThemePreferences {
  _RealThemePreferences(this.value);

  String? value;
  int failuresRemaining = 0;
  Completer<void>? gate;
  final List<String> writeAttempts = <String>[];

  @override
  String? readThemeMode() => value;

  @override
  Future<void> writeThemeMode(String value) async {
    writeAttempts.add(value);
    if (gate case final pending?) await pending.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('raw theme backend secret');
    }
    this.value = value;
  }
}

final class _SettingsThemeRetryScheduler implements ThemeRetryScheduler {
  final Completer<int> firstScheduled = Completer<int>();
  final List<Completer<void>> _scheduled = <Completer<void>>[];

  @override
  Future<void> wait(int failureCount) {
    if (!firstScheduled.isCompleted) firstScheduled.complete(failureCount);
    final completer = Completer<void>();
    _scheduled.add(completer);
    return completer.future;
  }

  void releaseNext() => _scheduled.removeAt(0).complete();
}

final class _ActionAuth implements FirebaseAuth {
  int signOutCalls = 0;
  Completer<void>? gate;
  int failuresRemaining = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (gate case final value?) await value.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('raw logout backend secret');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
