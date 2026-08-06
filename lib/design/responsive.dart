import 'package:gelatino/design/app_tokens.dart';

enum ResponsiveClass {
  compact,
  medium,
  wide;

  static ResponsiveClass fromWidth(double width) {
    if (width < AppBreakpoints.mediumMin) {
      return compact;
    }
    if (width < AppBreakpoints.wideMin) {
      return medium;
    }
    return wide;
  }

  double get horizontalPadding => switch (this) {
    compact => AppSpacing.md,
    medium => AppSpacing.lg,
    wide => AppSpacing.xl,
  };
}
