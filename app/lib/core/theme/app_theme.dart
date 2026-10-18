import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

@immutable
class EyeSenseColors extends ThemeExtension<EyeSenseColors> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderStrong;
  final Color focusRing;
  final Color error;
  final Color concern;
  final Color success;

  const EyeSenseColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.focusRing,
    required this.error,
    required this.concern,
    required this.success,
  });

  static const dark = EyeSenseColors(
    background: Color(0xFF0A0C10),
    surface: Color(0xFF14171D),
    surfaceRaised: Color(0xFF1C2029),
    surfaceSunken: Color(0xFF05070A),
    accent: Color(0xFFFFC247),
    onAccent: Color(0xFF1A1200),
    textPrimary: Color(0xFFF7F8F8),
    textSecondary: Color(0xFFB6BCC6),
    textTertiary: Color(0xFF878E99),
    border: Color(0xFF2A2F39),
    borderStrong: Color(0xFF3D434F),
    focusRing: Color(0xFFFFD86B),
    error: Color(0xFFFF8A7A),
    concern: Color(0xFFFFB020),
    success: Color(0xFF5FD39A),
  );

  static const light = EyeSenseColors(
    background: Color(0xFFFBFBF9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF2F3F0),
    surfaceSunken: Color(0xFFEDEEEA),
    accent: Color(0xFF8A5A00),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF14171D),
    textSecondary: Color(0xFF4A525E),
    textTertiary: Color(0xFF6B737F),
    border: Color(0xFFD8DAD4),
    borderStrong: Color(0xFFB4B7B0),
    focusRing: Color(0xFF8A5A00),
    error: Color(0xFFA8231A),
    concern: Color(0xFF7A4A00),
    success: Color(0xFF0F6B45),
  );

  static const maximumContrast = EyeSenseColors(
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceRaised: Color(0xFF000000),
    surfaceSunken: Color(0xFF000000),
    accent: Color(0xFFFFD400),
    onAccent: Color(0xFF000000),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFFFFFFF),
    textTertiary: Color(0xFFFFFFFF),
    border: Color(0xFFFFFFFF),
    borderStrong: Color(0xFFFFFFFF),
    focusRing: Color(0xFFFFD400),
    error: Color(0xFFFFD400),
    concern: Color(0xFFFFD400),
    success: Color(0xFFFFFFFF),
  );

  @override
  EyeSenseColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? accent,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? borderStrong,
    Color? focusRing,
    Color? error,
    Color? concern,
    Color? success,
  }) {
    return EyeSenseColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      focusRing: focusRing ?? this.focusRing,
      error: error ?? this.error,
      concern: concern ?? this.concern,
      success: success ?? this.success,
    );
  }

  @override
  EyeSenseColors lerp(ThemeExtension<EyeSenseColors>? other, double t) {
    if (other is! EyeSenseColors) return this;
    return EyeSenseColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      error: Color.lerp(error, other.error, t)!,
      concern: Color.lerp(concern, other.concern, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

class AppTheme {
  static const double primaryButtonHeight = 72.0;
  static const double minTouchTarget = 48.0;
  static const double defaultPadding = 16.0;
  static const double elementSpacing = 12.0;
  static const double radiusSmall = 8;
  static const double radiusMedium = 16;
  static const double radiusLarge = 28;
  static const double iconInline = 20;
  static const double iconStandard = 24;
  static const double iconPrimary = 32;

  static const String fontFamily = 'AtkinsonHyperlegible';

  static ThemeData get darkTheme => _build(EyeSenseColors.dark, Brightness.dark);
  static ThemeData get lightTheme => _build(EyeSenseColors.light, Brightness.light);
  static ThemeData get maximumContrastTheme => _build(EyeSenseColors.maximumContrast, Brightness.dark, contrast: true);

  static ThemeData themeFor(String mode, Brightness platform) {
    switch (mode) {
      case 'light':
        return lightTheme;
      case 'dark':
        return darkTheme;
      case 'contrast':
        return maximumContrastTheme;
      default:
        return platform == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  static ThemeData _build(EyeSenseColors colors, Brightness brightness, {bool contrast = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      contrastLevel: contrast ? 1 : 0.5,
    ).copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.error,
      onError: brightness == Brightness.dark ? colors.background : colors.surface,
      outline: colors.border,
      outlineVariant: colors.borderStrong,
    );

    final text = _textTheme(colors);
    final shapeMedium = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium));
    final focusSide = WidgetStateProperty.resolveWith<BorderSide?>((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: colors.focusRing, width: 3);
      }
      return BorderSide(color: colors.border, width: contrast ? 2 : 1);
    });

    ButtonStyle buttonStyle({required Color background, required Color foreground, Color? disabledForeground}) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.surfaceRaised;
          if (states.contains(WidgetState.pressed)) return background.withValues(alpha: 0.86);
          return background;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabledForeground ?? colors.textTertiary;
          return foreground;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return foreground.withValues(alpha: 0.12);
          if (states.contains(WidgetState.hovered)) return foreground.withValues(alpha: 0.08);
          return null;
        }),
        side: focusSide,
        minimumSize: const WidgetStatePropertyAll(Size(88, minTouchTarget)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        shape: WidgetStatePropertyAll(shapeMedium),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colors.background,
      colorScheme: scheme,
      extensions: [colors],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.linux: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shapeMedium,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceRaised,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: colors.accent,
        textColor: colors.textPrimary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: colors.textSecondary),
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        labelStyle: text.bodyMedium?.copyWith(color: colors.textSecondary),
        hintStyle: text.bodyMedium?.copyWith(color: colors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: colors.focusRing, width: 3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle(background: colors.accent, foreground: colors.onAccent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle(background: colors.accent, foreground: colors.onAccent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle(background: colors.surface, foreground: colors.textPrimary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle(background: Colors.transparent, foreground: colors.accent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          side: BorderSide(color: colors.focusRing, width: 0),
        ).copyWith(side: focusSide),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onAccent;
          return colors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return colors.surfaceSunken;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.border,
        thumbColor: colors.accent,
        overlayColor: colors.accent.withValues(alpha: 0.16),
        valueIndicatorColor: colors.surfaceRaised,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(color: colors.textPrimary),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(colors.accent)),
      checkboxTheme: CheckboxThemeData(fillColor: WidgetStatePropertyAll(colors.accent)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: text.bodyMedium?.copyWith(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: shapeMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(radiusSmall),
          border: Border.all(color: colors.border),
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.textPrimary),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: buttonStyle(background: colors.surfaceRaised, foreground: colors.textPrimary),
      ),
    );
  }

  static TextTheme _textTheme(EyeSenseColors colors) {
    TextStyle style(double size, FontWeight weight, double height, {double tracking = 0}) {
      return TextStyle(
        fontFamily: fontFamily,
        color: colors.textPrimary,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: tracking,
      );
    }

    return TextTheme(
      displayLarge: style(40, FontWeight.w700, 1.15, tracking: -0.5),
      displayMedium: style(33, FontWeight.w700, 1.2, tracking: -0.5),
      displaySmall: style(33, FontWeight.w700, 1.2, tracking: -0.5),
      headlineLarge: style(28, FontWeight.w700, 1.25, tracking: -0.25),
      headlineMedium: style(28, FontWeight.w700, 1.25, tracking: -0.25),
      headlineSmall: style(23, FontWeight.w700, 1.3),
      titleLarge: style(20, FontWeight.w700, 1.35),
      titleMedium: style(18, FontWeight.w700, 1.4),
      titleSmall: style(16, FontWeight.w700, 1.35),
      bodyLarge: style(18, FontWeight.w400, 1.55),
      bodyMedium: style(16, FontWeight.w400, 1.5),
      bodySmall: style(14, FontWeight.w400, 1.45).copyWith(color: colors.textSecondary),
      labelLarge: style(16, FontWeight.w700, 1.2, tracking: 0.1),
      labelMedium: style(14, FontWeight.w700, 1.2, tracking: 0.25),
      labelSmall: style(14, FontWeight.w700, 1.2, tracking: 0.25).copyWith(color: colors.textSecondary),
    );
  }
}

extension EyeSenseThemeContext on BuildContext {
  EyeSenseColors get eyeColors => Theme.of(this).extension<EyeSenseColors>() ?? EyeSenseColors.dark;
}
