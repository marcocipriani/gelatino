import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Official Gelatino palette
  static const Color fiorDiPanna = AppColors.fiorDiPanna;
  static const Color fondenteExtra = AppColors.fondente;
  static const Color fragolaPop = AppColors.fragola;
  static const Color mentaGlaciale = AppColors.menta;
  static const Color puffoElettrico = AppColors.puffo;
  static const Color sorbettoYuzu = AppColors.sorbetto;

  // Legacy aliases kept for existing widgets.
  static const Color strawberryVibrant = fragolaPop;
  static const Color strawberryPastel = fragolaPop;
  static const Color mintGreen = mentaGlaciale;
  static const Color mangoYellow = sorbettoYuzu;

  // Light Mode Color Palette
  static const Color lightScaffoldBg = fiorDiPanna;
  static const Color lightSurface = AppColors.lightSurface;
  static const Color lightText = fondenteExtra;
  static const Color lightBorder = AppColors.lightBorder;

  // Dark Mode Color Palette
  static const Color darkScaffoldBg = fondenteExtra;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkText = AppColors.darkText;
  static const Color darkBorder = AppColors.darkBorder;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: fragolaPop,
        secondary: mentaGlaciale,
        tertiary: sorbettoYuzu,
        surface: lightSurface,
        onPrimary: fondenteExtra,
        onSecondary: lightText,
        onTertiary: lightText,
        onSurface: lightText,
        error: AppColors.error,
        onError: Colors.white,
        shadow: Color(0x1AFF4D6D),
      ),
      scaffoldBackgroundColor: lightScaffoldBg,
      cardColor: lightSurface,
      dividerColor: lightBorder,
      shadowColor: const Color(0x1AFF4D6D),
      focusColor: const Color(0x29FF4D6D),
      hoverColor: const Color(0x14FF4D6D),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    final textThemeBase = GoogleFonts.plusJakartaSansTextTheme();

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: textThemeBase.displayLarge?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 36,
          letterSpacing: 36 * -0.02,
        ),
        displayMedium: textThemeBase.displayMedium?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: 32 * -0.02,
        ),
        displaySmall: textThemeBase.displaySmall?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: 28 * -0.02,
        ),
        headlineLarge: textThemeBase.headlineLarge?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: 24 * -0.02,
        ),
        headlineMedium: textThemeBase.headlineMedium?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: 22 * -0.02,
        ),
        headlineSmall: textThemeBase.headlineSmall?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 20 * -0.02,
        ),
        titleLarge: textThemeBase.titleLarge?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 20 * -0.02,
        ),
        titleMedium: textThemeBase.titleMedium?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 18 * -0.02,
        ),
        titleSmall: textThemeBase.titleSmall?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 16 * -0.02,
        ),
        bodyLarge: textThemeBase.bodyLarge?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyMedium: textThemeBase.bodyMedium?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodySmall: textThemeBase.bodySmall?.copyWith(
          color: lightText.withValues(alpha: 0.7),
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        labelLarge: textThemeBase.labelLarge?.copyWith(
          color: lightText,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        labelMedium: textThemeBase.labelMedium?.copyWith(
          color: lightText,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        labelSmall: textThemeBase.labelSmall?.copyWith(
          color: lightText,
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
      ),

      // AppBar Theme (SliverAppBar customizes on top of this)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: lightText, size: 24),
        actionsIconTheme: const IconThemeData(color: lightText, size: 24),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: lightText,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: 32 * -0.02,
        ),
      ),

      // Ordinary content surfaces are flat. Overlays opt into elevation locally.
      cardTheme: CardThemeData(
        elevation: AppElevation.flat,
        shadowColor: Colors.transparent,
        color: lightSurface,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppRadii.card,
            cornerSmoothing: 0.6,
          ),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
      ),

      // All interactive controls reserve the A1 minimum target.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: fragolaPop,
          foregroundColor: fondenteExtra,
          elevation: AppElevation.flat,
          minimumSize: const Size(88, AppLayout.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: AppRadii.control,
              cornerSmoothing: 0.6,
            ),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.fragolaInk,
          minimumSize: const Size(AppLayout.touchTarget, AppLayout.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fragolaPop,
          foregroundColor: fondenteExtra,
          minimumSize: const Size(88, AppLayout.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          minimumSize: const Size(88, AppLayout.touchTarget),
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: lightText,
          minimumSize: const Size.square(AppLayout.touchTarget),
          padding: const EdgeInsets.all(AppSpacing.sm),
        ),
      ),

      // FAB Theme (Stencil border, minimum touch target size 56x56)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fragolaPop,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppRadii.hero,
            cornerSmoothing: 0.6,
          ),
          side: const BorderSide(color: lightScaffoldBg, width: 4),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: lightBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(
            color: fragolaPop,
            width: AppFocus.ringWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: fragolaPop,
        secondary: mentaGlaciale,
        tertiary: sorbettoYuzu,
        surface: darkSurface,
        onPrimary: fondenteExtra,
        onSecondary: fondenteExtra,
        onTertiary: fondenteExtra,
        onSurface: darkText,
        error: AppColors.darkError,
        onError: AppColors.onDarkError,
        shadow: Colors.transparent,
      ),
      scaffoldBackgroundColor: darkScaffoldBg,
      cardColor: darkSurface,
      dividerColor: darkBorder,
      shadowColor: Colors.transparent,
      focusColor: const Color(0x52FF4D6D),
      hoverColor: const Color(0x29FF4D6D),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    final textThemeBase = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: textThemeBase.displayLarge?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 36,
          letterSpacing: 36 * -0.02,
        ),
        displayMedium: textThemeBase.displayMedium?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: 32 * -0.02,
        ),
        displaySmall: textThemeBase.displaySmall?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: 28 * -0.02,
        ),
        headlineLarge: textThemeBase.headlineLarge?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: 24 * -0.02,
        ),
        headlineMedium: textThemeBase.headlineMedium?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: 22 * -0.02,
        ),
        headlineSmall: textThemeBase.headlineSmall?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 20 * -0.02,
        ),
        titleLarge: textThemeBase.titleLarge?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: 20 * -0.02,
        ),
        titleMedium: textThemeBase.titleMedium?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 18 * -0.02,
        ),
        titleSmall: textThemeBase.titleSmall?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 16 * -0.02,
        ),
        bodyLarge: textThemeBase.bodyLarge?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyMedium: textThemeBase.bodyMedium?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodySmall: textThemeBase.bodySmall?.copyWith(
          color: darkText.withValues(alpha: 0.7),
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        labelLarge: textThemeBase.labelLarge?.copyWith(
          color: darkText,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        labelMedium: textThemeBase.labelMedium?.copyWith(
          color: darkText,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        labelSmall: textThemeBase.labelSmall?.copyWith(
          color: darkText,
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkText, size: 24),
        actionsIconTheme: const IconThemeData(color: darkText, size: 24),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: darkText,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: 32 * -0.02,
        ),
      ),

      // Card Theme (In Dark Mode, replace shadows with thin borders 0.5px and dark surface)
      cardTheme: CardThemeData(
        elevation: AppElevation.flat,
        shadowColor: Colors.transparent,
        color: darkSurface,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppRadii.card,
            cornerSmoothing: 0.6,
          ),
          side: const BorderSide(color: darkBorder, width: 0.5),
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
          minimumSize: const Size(88, AppLayout.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: AppRadii.control,
              cornerSmoothing: 0.6,
            ),
            side: const BorderSide(color: darkBorder, width: 0.5),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fragolaPop,
          minimumSize: const Size(AppLayout.touchTarget, AppLayout.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fragolaPop,
          foregroundColor: fondenteExtra,
          minimumSize: const Size(88, AppLayout.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          minimumSize: const Size(88, AppLayout.touchTarget),
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkText,
          minimumSize: const Size.square(AppLayout.touchTarget),
          padding: const EdgeInsets.all(AppSpacing.sm),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fragolaPop,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppRadii.hero,
            cornerSmoothing: 0.6,
          ),
          side: const BorderSide(color: darkScaffoldBg, width: 4),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: darkBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: darkBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(
            color: fragolaPop,
            width: AppFocus.ringWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.error, width: 0.5),
        ),
      ),
    );
  }
}
