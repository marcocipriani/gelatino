import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';

const highContrastPreferenceKey = 'gelatino_high_contrast';

/// In-app switch, because Android and most browsers never report the OS
/// high-contrast setting to Flutter.
// ponytail: per device, not synced to the profile. Move it to UserSettings
// (and firestore.rules) if it ever has to follow the account.
class HighContrastNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(highContrastPreferenceKey) ??
      false;

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(highContrastPreferenceKey, value);
  }
}

final highContrastProvider = NotifierProvider<HighContrastNotifier, bool>(
  HighContrastNotifier.new,
);
