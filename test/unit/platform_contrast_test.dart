import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/theme/app_theme.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance() + 0.05;
  final y = b.computeLuminance() + 0.05;
  return x > y ? x / y : y / x;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system bars, picker month and switch track stay legible', () {
    for (final theme in [
      AppTheme.lightTheme,
      AppTheme.darkTheme,
      AppTheme.highContrastLightTheme,
      AppTheme.highContrastDarkTheme,
    ]) {
      final colors = theme.colorScheme;
      final bars = AppTheme.systemBars(theme);
      expect(bars.statusBarBrightness, theme.brightness);
      expect(bars.statusBarIconBrightness, isNot(theme.brightness));
      expect(bars.systemNavigationBarIconBrightness, isNot(theme.brightness));
      expect(
        _ratio(
          theme.datePickerTheme.subHeaderForegroundColor!,
          colors.surfaceContainerHigh,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(_ratio(colors.outline, colors.surface), greaterThanOrEqualTo(3));
      final thumb = theme.switchTheme.thumbColor!.resolve(<WidgetState>{})!;
      expect(_ratio(thumb, colors.outline), greaterThanOrEqualTo(3));
    }
  });
}
