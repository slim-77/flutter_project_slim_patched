import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceHigh = Color(0xFF1F2630);
  static const border = Color(0xFF2A323D);
  static const primary = Color(0xFF22D3EE);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const textMuted = Color(0xFF8B96A5);
}

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        // الإطار مضيء بلون السيان دائماً (حتى بدون تركيز)
        border: border(AppColors.primary, 1.4),
        enabledBorder: border(AppColors.primary, 1.4),
        focusedBorder: border(AppColors.primary, 2),
        errorBorder: border(AppColors.danger, 1.4),
        focusedErrorBorder: border(AppColors.danger, 2),
        // كل النصوص داخل المربعات بنفس لون الإطار
        labelStyle: const TextStyle(color: AppColors.primary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        hintStyle: const TextStyle(color: AppColors.primary),
        helperStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
