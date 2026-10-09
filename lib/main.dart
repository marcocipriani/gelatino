import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase/emulator_config.dart';
import 'firebase/firebase_providers.dart';
import 'firebase_options.dart';
import 'providers/profile_lifecycle_bindings.dart';
import 'providers/check_in_flow_provider.dart';
import 'repositories/check_in_draft_repository.dart';
import 'repositories/check_in_label_repository.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'constants/app_strings.dart';
import 'services/media_cache/media_disk_cache.dart';
import 'services/media_cache/platform_media_disk_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = firebaseOptionsForRuntime(
    base: DefaultFirebaseOptions.currentPlatform,
    isDebug: kDebugMode,
    useFirebaseEmulators: const bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
  );
  await Firebase.initializeApp(options: firebaseOptions);

  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final firebaseStorage = FirebaseStorage.instance;

  await configureFirebaseEmulators(
    auth: firebaseAuth,
    firestore: firestore,
    functions: functions,
    storage: firebaseStorage,
  );

  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (e) {
      debugPrint("Errore GoogleSignIn.initialize: $e");
    }
  }

  if (kIsWeb) {
    try {
      await firebaseAuth.getRedirectResult();
    } catch (e) {
      debugPrint("Errore getRedirectResult: $e");
    }
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        mediaDiskCacheProvider.overrideWithValue(
          createPlatformMediaDiskCache(),
        ),
        checkInLabelRepositoryProvider.overrideWithValue(
          PersistentCheckInLabelRepository(
            SharedPreferencesDraftPreferences(sharedPreferences),
          ),
        ),
      ],
      child: const GelatinoApp(),
    ),
  );
}

class GelatinoApp extends ConsumerWidget {
  const GelatinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return ProfileLifecycleBindings(
      child: MaterialApp.router(
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
