import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/firebase/firebase_providers.dart';
import 'package:gelatino/providers/high_contrast_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('high contrast is off by default and survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    ProviderContainer launch() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      return container;
    }

    final first = launch();
    expect(first.read(highContrastProvider), isFalse);
    await first.read(highContrastProvider.notifier).set(true);
    expect(first.read(highContrastProvider), isTrue);
    expect(launch().read(highContrastProvider), isTrue);
  });
}
