import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF08090B);
  static const surface = Color(0xFF14161A);
  static const panel = Color(0xFF22252B);
  static const steel = Color(0xFF565D68);
  static const text = Color(0xFFF3F5F7);
  static const textSecondary = Color(0xFFA6ADB8);
  static const muted = Color(0xFF707783);
  static const beam = Color(0xFFF3F5F7);
}

class AppTheme {
  static ThemeData get dark {
    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w800,
        fontSize: 40,
        height: 1.05,
        color: AppColors.text,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w800,
        fontSize: 28,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.4,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.4,
        color: AppColors.text,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.6,
        color: AppColors.text,
      ),
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.text,
        secondary: AppColors.steel,
      ),
      fontFamily: 'Manrope',
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.text,
        inactiveTrackColor: AppColors.steel,
        thumbColor: AppColors.text,
        overlayColor: Color(0x22F3F5F7),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.steel
              : AppColors.panel,
        ),
      ),
    );
  }
}

class Motion {
  static bool reduced = false;

  static Duration get transition =>
      Duration(milliseconds: reduced ? 90 : 220);
}

class AppInfo {
  static const version = '1.0.0';
}
