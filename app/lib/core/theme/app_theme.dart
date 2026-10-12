import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colours
  static const Color backgroundNavy = Color(0xFF0A1128);
  static const Color surfaceNavy = Color(0xFF131F3D);
  static const Color surfaceVariant = Color(0xFF1D2D50);
  static const Color textNearWhite = Color(0xFFF8F9FA);
  static const Color textMuted = Color(0xFFD0D7DE);
  static const Color tealAccent = Color(0xFF20B2AA);
  static const Color tealLight = Color(0xFF48D1CC);
  static const Color errorRed = Color(0xFFFF6B6B);
  static const Color warningOrange = Color(0xFFFFB347);

  // Accessible Minimum Sizes
  static const double minTouchTarget = 48.0;
  static const double primaryButtonHeight = 64.0;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundNavy,
      colorScheme: const ColorScheme.dark(
        primary: tealAccent,
        onPrimary: backgroundNavy,
        secondary: tealLight,
        onSecondary: backgroundNavy,
        surface: surfaceNavy,
        onSurface: textNearWhite,
        error: errorRed,
        onError: backgroundNavy,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textNearWhite,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          color: textNearWhite,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: textNearWhite,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textNearWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textNearWhite,
          fontSize: 18,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textMuted,
          fontSize: 16,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: textNearWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundNavy,
        foregroundColor: textNearWhite,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, primaryButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
