import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'app_design.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.promptTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3F2FD),
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.expense,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _addEmojiFallbacks(
        baseTextTheme.copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.textPrimaryLight),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.textPrimaryLight),
          bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        titleTextStyle: GoogleFonts.prompt(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 0.5,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.dividerLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.dividerLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.prompt(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          side: const BorderSide(color: AppColors.dividerLight),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.promptTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDarkBrand,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF2E1C2B),
        onPrimaryContainer: Color(0xFFFF8FA3),
        secondary: Color(0xFFFF8E72),
        onSecondary: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        outline: AppColors.dividerDark,
        outlineVariant: AppColors.dividerDark,
        error: AppColors.expenseDark,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _addEmojiFallbacks(
        baseTextTheme.copyWith(
          displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
          titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
          titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.textPrimaryDark),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: const Color(0xFFCBD0E0)),
          bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.textSecondaryDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        titleTextStyle: GoogleFonts.prompt(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dividerDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.dividerDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryDarkBrand, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.expenseDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkBrand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.prompt(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDarkBrand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          side: const BorderSide(color: AppColors.dividerDark),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 0.8,
        space: 1,
      ),
    );
  }

  static TextTheme _addEmojiFallbacks(TextTheme textTheme) {
    const fallbacks = [
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Noto Color Emoji',
      'Android Emoji',
      'sans-serif',
    ];
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(fontFamilyFallback: fallbacks),
      displayMedium: textTheme.displayMedium?.copyWith(fontFamilyFallback: fallbacks),
      displaySmall: textTheme.displaySmall?.copyWith(fontFamilyFallback: fallbacks),
      headlineLarge: textTheme.headlineLarge?.copyWith(fontFamilyFallback: fallbacks),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontFamilyFallback: fallbacks),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontFamilyFallback: fallbacks),
      titleLarge: textTheme.titleLarge?.copyWith(fontFamilyFallback: fallbacks),
      titleMedium: textTheme.titleMedium?.copyWith(fontFamilyFallback: fallbacks),
      titleSmall: textTheme.titleSmall?.copyWith(fontFamilyFallback: fallbacks),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontFamilyFallback: fallbacks),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontFamilyFallback: fallbacks),
      bodySmall: textTheme.bodySmall?.copyWith(fontFamilyFallback: fallbacks),
      labelLarge: textTheme.labelLarge?.copyWith(fontFamilyFallback: fallbacks),
      labelMedium: textTheme.labelMedium?.copyWith(fontFamilyFallback: fallbacks),
      labelSmall: textTheme.labelSmall?.copyWith(fontFamilyFallback: fallbacks),
    );
  }
}
