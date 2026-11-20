import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Purple Mode ("Obsidian Violet Audio") color palette calibrated for
/// dark-room immersion and Stitch UI fidelity.
class AppColors {
  AppColors._();

  // Primary Canvas & Surfaces
  static const Color backgroundPrimary = Color(0xFF0D0A14);
  static const Color backgroundSecondary = Color(0xFF120B20);
  static const Color surfaceBase = Color(0xFF15121C);
  static const Color surfaceCard = Color(0xFF181226);
  static const Color surfaceContainer = Color(0xFF211E29);
  static const Color surfaceContainerHigh = Color(0xFF2C2833);
  static const Color surfaceContainerHighest = Color(0xFF37333E);
  static const Color surfaceDeepPlum = Color(0xFF24163B);

  // Lyrics Surfaces
  static const Color lyricsCardSurface = Color(0xFF3C096C);
  static const Color lyricsFullBackdrop = Color(0xFF240046);

  // Purple Accents
  static const Color primaryAccent = Color(0xFF9D4EDD); // Electric Neon Purple
  static const Color secondaryAccent = Color(0xFF7B2CBF); // Vibrant Amethyst
  static const Color tertiaryLilac = Color(0xFFC77DFF); // Vivid Lilac
  static const Color softLavender = Color(0xFFE0B6FF);
  static const Color badgeContainer = Color(0xFF6B13AF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textOnSurface = Color(0xFFE7E0EF);
  static const Color textSecondary = Color(0xFFA89EC9);
  static const Color textMuted = Color(0xFF998D9E);
  static const Color textUpcomingLyric = Color(0xFFC77DFF);

  // Borders & Dividers
  static const Color borderPurpleSubtle = Color(0x269D4EDD);
  static const Color borderHairline = Color(0x14FFFFFF);
  static const Color error = Color(0xFFFFB4AB);
  static const Color emerald = Color(0xFF34D399);
}

class AppTheme {
  AppTheme._();

  static ThemeData darkTheme() {
    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      canvasColor: AppColors.backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryAccent,
        onPrimary: AppColors.textPrimary,
        primaryContainer: AppColors.primaryAccent,
        onPrimaryContainer: AppColors.textPrimary,
        secondary: AppColors.secondaryAccent,
        onSecondary: AppColors.textPrimary,
        secondaryContainer: AppColors.badgeContainer,
        onSecondaryContainer: AppColors.softLavender,
        tertiary: AppColors.tertiaryLilac,
        surface: AppColors.surfaceCard,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.error,
        outline: AppColors.textMuted,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderHairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        modalBackgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderPurpleSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDeepPlum,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderPurpleSubtle),
        ),
      ),
    );
  }

  /// Tabular numeric style for playback timestamps and durations.
  static TextStyle tabularTimeStyle({
    double fontSize = 12,
    Color color = AppColors.textSecondary,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
