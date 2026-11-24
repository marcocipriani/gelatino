import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const compactMax = 599.0;
  static const mediumMin = 600.0;
  static const mediumMax = 1023.0;
  static const wideMin = 1024.0;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const display = 64.0;
}

abstract final class AppRadii {
  static const control = 14.0;
  static const card = 20.0;
  static const hero = 24.0;
  static const pill = 999.0;
}

abstract final class AppLayout {
  static const maxContent = 1280.0;
  static const readableText = 680.0;
  static const feed = 680.0;
  static const touchTarget = 44.0;

  /// Check-in photos are framed at this ratio in the check-in cropper and
  /// shown at it in the feed card, so what the author frames is what friends
  /// see.
  static const checkInPhotoAspectRatio = 16 / 9;
}

abstract final class AppElevation {
  static const flat = 0.0;
  static const overlay = 8.0;
}

abstract final class AppColors {
  static const fiorDiPanna = Color(0xFFFAFAFA);
  static const fondente = Color(0xFF1A1A1A);
  static const fragola = Color(0xFFFF4D6D);
  static const fragolaInk = Color(0xFFB0003A);
  static const menta = Color(0xFF00E6B8);
  static const puffo = Color(0xFF00BFFF);
  static const sorbetto = Color(0xFFFFEA00);

  static const action = fragola;
  static const success = menta;
  static const information = puffo;
  static const warning = sorbetto;

  static const lightSurface = Color(0xFFFFFFFF);
  static const lightFill = Color(0xFFEDEDED);
  static const lightFillStrong = Color(0xFFE2E2E2);
  static const lightSecondaryText = Color(0xFF454545);
  static const lightBorder = Color(0xFFD4D4D4);
  static const lightOutline = Color(0xFF767676);
  static const lightTint = Color(0xFFFFE3E8);

  static const darkSurface = Color(0xFF242424);
  static const darkFill = Color(0xFF303030);
  static const darkFillStrong = Color(0xFF3A3A3A);
  static const darkText = Color(0xFFF5F5F5);
  static const darkSecondaryText = Color(0xFFCCCCCC);
  static const darkBorder = Color(0xFF484848);
  static const darkOutline = Color(0xFF969696);
  static const darkTint = Color(0xFF4A1F28);
  static const darkAccentInk = Color(0xFFFFA3B3);
  static const error = Color(0xFFBA1A1A);
  static const darkError = Color(0xFFFFB4AB);
  static const onDarkError = Color(0xFF690005);
}

abstract final class AppFocus {
  static const ringWidth = 2.0;
  static const ringGap = 2.0;
  static const animationDuration = Duration(milliseconds: 120);
  static const color = AppColors.fragola;
}

/// Fragola is 3.1:1 on Fior di Panna: good for fills, too weak for text.
/// Coloured text and small icons on neutral surfaces use [accentInk] instead.
extension AppSchemeColors on ColorScheme {
  Color get accentInk => onPrimaryContainer;
}

const _deepestInk = Color(0xFF050505);

/// Fondente or white ink, whichever reads better on an arbitrary fill
/// such as a user-picked flavour colour.
Color inkOn(Color fill) {
  final luminance = fill.computeLuminance();
  final onWhite = 1.05 / (luminance + 0.05);
  final onFondente =
      (luminance + 0.05) / (AppColors.fondente.computeLuminance() + 0.05);
  if (onFondente >= 4.5 && onFondente >= onWhite) return AppColors.fondente;
  if (onWhite >= 4.5) return Colors.white;
  // Mid-tones defeat both. One shade deeper than Fondente clears AA and
  // still isn't pure black.
  return _deepestInk;
}
