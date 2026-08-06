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
  static const control = 10.0;
  static const card = 20.0;
  static const hero = 24.0;
  static const pill = 999.0;
}

abstract final class AppLayout {
  static const maxContent = 1280.0;
  static const readableText = 680.0;
  static const feed = 680.0;
  static const touchTarget = 44.0;
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
  static const lightBorder = Color(0xFFEEEEEE);
  static const darkSurface = Color(0xFF242424);
  static const darkText = Color(0xFFF5F5F5);
  static const darkBorder = Color(0xFF3B3B3B);
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
