import 'package:flutter/material.dart';

class AppTheme {
  // Sizing standards from Refined Build Prompt (Section 5.2)
  static const double primaryButtonHeight = 72.0;
  static const double minTouchTarget = 48.0;
  static const double defaultPadding = 20.0;
  static const double elementSpacing = 16.0;

  // Dark Theme Tokens (Refined Section 5.2)
  static const Color darkBackground = Color(0xFF0B1630);
  static const Color darkSurface = Color(0xFF15243E);
  static const Color darkMainText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFD7E2F0);
  static const Color darkPrimaryFill = Color(0xFF35D6C4);
  static const Color darkTextOnPrimary = Color(0xFF0B1630);
  static const Color darkFocusIndicator = Color(0xFF35D6C4);
  static const Color darkError = Color(0xFFFCA5A5);
  static const Color darkWarning = Color(0xFFFCD34D);

  // Light Theme Tokens (Refined Section 5.2)
  static const Color lightBackground = Color(0xFFF7F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightMainText = Color(0xFF0B1630);
  static const Color lightSecondaryText = Color(0xFF34445C);
  static const Color lightPrimaryFill = Color(0xFF006B63);
  static const Color lightTextOnPrimary = Color(0xFFFFFFFF);
  static const Color lightFocusIndicator = Color(0xFF006B63);
  static const Color lightError = Color(0xFFB42318);
  static const Color lightWarning = Color(0xFF744210);

  // Backward-compatible color aliases
  static const Color backgroundNavy = darkBackground;
  static const Color surfaceNavy = darkSurface;
  static const Color surfaceVariant = Color(0xFF1D2D50);
  static const Color textNearWhite = darkMainText;
  static const Color textMuted = darkSecondaryText;
  static const Color tealAccent = darkPrimaryFill;
  static const Color tealLight = Color(0xFF48D1CC);
  static const Color errorRed = darkError;
  static const Color warningOrange = darkWarning;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimaryFill,
        onPrimary: darkTextOnPrimary,
        surface: darkSurface,
        onSurface: darkMainText,
        error: darkError,
        onError: darkBackground,
        outline: Color(0xFF334B6E),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: darkMainText,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: darkMainText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF132240),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334B6E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334B6E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkPrimaryFill, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: darkMainText,
          fontSize: 30,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          color: darkMainText,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: darkMainText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: darkMainText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: darkMainText,
          fontSize: 18,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: darkSecondaryText,
          fontSize: 16,
          height: 1.4,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88.0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightPrimaryFill,
        onPrimary: lightTextOnPrimary,
        surface: lightSurface,
        onSurface: lightMainText,
        error: lightError,
        onError: lightTextOnPrimary,
        outline: Color(0xFFBAC5D5),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: lightBackground,
        foregroundColor: lightMainText,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          color: lightMainText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFBAC5D5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFBAC5D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimaryFill, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: lightMainText,
          fontSize: 30,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          color: lightMainText,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: lightMainText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: lightMainText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: lightMainText,
          fontSize: 18,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: lightSecondaryText,
          fontSize: 16,
          height: 1.4,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88.0, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
