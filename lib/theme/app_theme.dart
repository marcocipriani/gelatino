import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder, CupertinoThemeData;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/design/motion.dart';

class AppTheme {
  // Official Gelatino palette
  static const Color fiorDiPanna = AppColors.fiorDiPanna;
  static const Color fondenteExtra = AppColors.fondente;
  static const Color fragolaPop = AppColors.fragola;
  static const Color mentaGlaciale = AppColors.menta;
  static const Color puffoElettrico = AppColors.puffo;
  static const Color sorbettoYuzu = AppColors.sorbetto;

  /// Declared in pubspec.yaml with its five real weights.
  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get lightTheme => _build(_light);
  static ThemeData get darkTheme => _build(_dark);
  static ThemeData get highContrastLightTheme => _build(_lightHighContrast);
  static ThemeData get highContrastDarkTheme => _build(_darkHighContrast);

  // Every role is set on purpose: an omitted role silently falls back to
  // surface, onSurface or a neon accent.
  static const _light = ColorScheme.light(
    primary: fragolaPop,
    onPrimary: fondenteExtra,
    primaryContainer: AppColors.lightTint,
    onPrimaryContainer: AppColors.fragolaInk,
    secondary: mentaGlaciale,
    onSecondary: fondenteExtra,
    secondaryContainer: AppColors.lightFill,
    onSecondaryContainer: fondenteExtra,
    tertiary: sorbettoYuzu,
    onTertiary: fondenteExtra,
    tertiaryContainer: sorbettoYuzu,
    onTertiaryContainer: fondenteExtra,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: AppColors.lightSurface,
    onSurface: fondenteExtra,
    onSurfaceVariant: AppColors.lightSecondaryText,
    surfaceContainerLowest: AppColors.lightSurface,
    surfaceContainerLow: AppColors.lightSurface,
    surfaceContainer: AppColors.lightFill,
    surfaceContainerHigh: AppColors.lightFill,
    surfaceContainerHighest: AppColors.lightFillStrong,
    surfaceTint: Colors.transparent,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightBorder,
    inverseSurface: fondenteExtra,
    onInverseSurface: fiorDiPanna,
    inversePrimary: AppColors.darkAccentInk,
    shadow: fondenteExtra,
    scrim: fondenteExtra,
  );

  static const _dark = ColorScheme.dark(
    primary: fragolaPop,
    onPrimary: fondenteExtra,
    primaryContainer: AppColors.darkTint,
    onPrimaryContainer: AppColors.darkAccentInk,
    secondary: mentaGlaciale,
    onSecondary: fondenteExtra,
    secondaryContainer: AppColors.darkFillStrong,
    onSecondaryContainer: AppColors.darkText,
    tertiary: sorbettoYuzu,
    onTertiary: fondenteExtra,
    tertiaryContainer: sorbettoYuzu,
    onTertiaryContainer: fondenteExtra,
    error: AppColors.darkError,
    onError: AppColors.onDarkError,
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkText,
    onSurfaceVariant: AppColors.darkSecondaryText,
    surfaceContainerLowest: AppColors.darkSurface,
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkFill,
    surfaceContainerHigh: AppColors.darkFill,
    surfaceContainerHighest: AppColors.darkFillStrong,
    surfaceTint: Colors.transparent,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkBorder,
    inverseSurface: fiorDiPanna,
    onInverseSurface: fondenteExtra,
    inversePrimary: AppColors.fragolaInk,
    shadow: fondenteExtra,
    scrim: fondenteExtra,
  );

  // iOS "Increase Contrast": borders become ink and secondary text goes 7:1+.
  static final _lightHighContrast = _light.copyWith(
    onPrimaryContainer: const Color(0xFF780026),
    onSurfaceVariant: fondenteExtra,
    outline: fondenteExtra,
    outlineVariant: AppColors.lightSecondaryText,
    error: const Color(0xFF8C0009),
  );

  static final _darkHighContrast = _dark.copyWith(
    onPrimaryContainer: const Color(0xFFFFD0D8),
    onSurfaceVariant: fiorDiPanna,
    outline: fiorDiPanna,
    outlineVariant: AppColors.darkSecondaryText,
  );

  static SmoothRectangleBorder _squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => SmoothRectangleBorder(
    borderRadius: SmoothBorderRadius(
      cornerRadius: radius,
      cornerSmoothing: 0.6,
    ),
    side: side,
  );

  static TextTheme _textTheme(ColorScheme colors) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = 1.3,
      double tracking = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * tracking,
      color: color ?? colors.onSurface,
    );

    const heavy = FontWeight.w800;
    const bold = FontWeight.w700;
    const semibold = FontWeight.w600;
    const medium = FontWeight.w500;
    // iOS Dynamic Type ramp, one weight up because Jakarta runs lighter than SF.
    return TextTheme(
      displayLarge: style(40, heavy, height: 1.1, tracking: -0.02),
      displayMedium: style(36, heavy, height: 1.12, tracking: -0.02),
      displaySmall: style(32, heavy, height: 1.15, tracking: -0.02),
      headlineLarge: style(28, heavy, height: 1.18, tracking: -0.015),
      headlineMedium: style(26, heavy, height: 1.2, tracking: -0.015),
      headlineSmall: style(22, heavy, height: 1.22, tracking: -0.01),
      titleLarge: style(20, bold, height: 1.25, tracking: -0.005),
      titleMedium: style(17, bold),
      titleSmall: style(16, bold),
      bodyLarge: style(17, medium, height: 1.4),
      bodyMedium: style(16, medium, height: 1.4),
      bodySmall: style(
        14,
        medium,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: style(16, bold, height: 1.25),
      labelMedium: style(14, semibold, height: 1.25),
      labelSmall: style(13, semibold, height: 1.2),
    );
  }

  /// System bar icons follow the app theme, which can differ from the OS one.
  static SystemUiOverlayStyle systemBars(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final ink = dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ink,
      statusBarBrightness: theme.brightness, // iOS names the background.
      systemNavigationBarColor: theme.colorScheme.surface,
      systemNavigationBarIconBrightness: ink,
    );
  }

  static ThemeData _build(ColorScheme colors) {
    final dark = colors.brightness == Brightness.dark;
    final canvas = dark ? fondenteExtra : fiorDiPanna;
    final text = _textTheme(colors);
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final controlShape = _squircle(AppRadii.control);
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );
    const buttonSize = Size(88, 48);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      canvasColor: colors.surface,
      cardColor: colors.surface,
      dividerColor: colors.outlineVariant,
      shadowColor: fondenteExtra.withValues(alpha: 0.2),
      hintColor: colors.onSurfaceVariant,
      focusColor: fragolaPop.withValues(alpha: dark ? 0.32 : 0.16),
      hoverColor: fragolaPop.withValues(alpha: dark ? 0.16 : 0.08),
      // iOS highlights on press; it never ripples.
      splashFactory: apple ? NoSplash.splashFactory : null,
      highlightColor: colors.onSurface.withValues(alpha: 0.08),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: colors.brightness,
        primaryColor: colors.accentInk,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentInk,
        selectionColor: fragolaPop.withValues(alpha: 0.32),
        selectionHandleColor: fragolaPop,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: MotionAwareTransitionsBuilder(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: MotionAwareTransitionsBuilder(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.android: MotionAwareTransitionsBuilder(
            PredictiveBackPageTransitionsBuilder(),
          ),
          TargetPlatform.linux: MotionAwareTransitionsBuilder(
            FadeForwardsPageTransitionsBuilder(),
          ),
          TargetPlatform.windows: MotionAwareTransitionsBuilder(
            FadeForwardsPageTransitionsBuilder(),
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: colors.onSurface, size: 24),
        titleTextStyle: text.titleMedium,
        shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      // Ordinary content surfaces are flat. Overlays opt into elevation locally.
      cardTheme: CardThemeData(
        elevation: AppElevation.flat,
        shadowColor: Colors.transparent,
        color: colors.surface,
        shape: _squircle(
          AppRadii.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: fragolaPop,
          foregroundColor: fondenteExtra,
          elevation: AppElevation.flat,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      // No colours here: they would also override FilledButton.tonal.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surface,
          minimumSize: buttonSize,
          padding: buttonPadding,
          side: BorderSide(color: colors.outline),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentInk,
          minimumSize: const Size(AppLayout.touchTarget, AppLayout.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      // No foreground here: it would also override IconButton.filled.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppLayout.touchTarget),
          padding: const EdgeInsets.all(AppSpacing.xs),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fragolaPop,
        foregroundColor: fondenteExtra,
        elevation: AppElevation.flat,
        shape: _squircle(AppRadii.card),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        floatingLabelStyle: text.labelLarge?.copyWith(color: colors.accentInk),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        border: inputBorder(colors.outline),
        enabledBorder: inputBorder(colors.outline),
        focusedBorder: inputBorder(fragolaPop, AppFocus.ringWidth),
        errorBorder: inputBorder(colors.error, 1.5),
        focusedErrorBorder: inputBorder(colors.error, AppFocus.ringWidth),
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? fragolaPop
              : colors.surface,
        ),
        checkmarkColor: fondenteExtra,
        iconTheme: IconThemeData(color: colors.accentInk, size: 18),
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? fondenteExtra
                : colors.onSurface,
          ),
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? fragolaPop
                : colors.outline,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: colors.outline, width: 2),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? fragolaPop
              : colors.outline,
        ),
        // Off, the track is ink: white would vanish on it in dark mode.
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : colors.surface,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      // The stock month label is onSurface at 60%, under AA on the dialog.
      datePickerTheme: DatePickerThemeData(
        subHeaderForegroundColor: colors.onSurfaceVariant,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurface,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        minTileHeight: 56,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentInk,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        barrierColor: fondenteExtra.withValues(alpha: 0.56),
        shape: _squircle(AppRadii.hero),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: canvas,
        modalBackgroundColor: canvas,
        modalBarrierColor: fondenteExtra.withValues(alpha: 0.56),
        showDragHandle: true,
        dragHandleColor: colors.outline,
        dragHandleSize: const Size(36, 5),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.labelMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: controlShape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
        textStyle: text.labelSmall?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}
