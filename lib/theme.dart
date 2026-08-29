import 'package:flutter/material.dart';

/// Central place for LifeSync AI's colours, text styles, and spacing.
///
/// Every screen should pull its look from here (via `Theme.of(context)` or
/// the constants below) instead of hardcoding colours/sizes, so the whole
/// app stays visually consistent.
///
/// These are the app's brand accent colours - they stay the same in both
/// light and dark mode. Surface/background/text colours differ per theme,
/// so those come from `Theme.of(context)` (via [AppThemeColors]) instead of
/// living here.
class AppColors {
  AppColors._();

  // Calm teal as the primary brand colour - fits a "health & wellbeing" app.
  static const Color primary = Color(0xFF2A9D8F);
  static const Color primaryDark = Color(0xFF1E7268);
  static const Color secondary = Color(0xFFE9C46A);

  static const Color background = Color(0xFFF7F9F9);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1B1B1F);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color success = Color(0xFF2A9D8F);
  static const Color warning = Color(0xFFE9C46A);
  static const Color error = Color(0xFFE76F51);

  // Dark-mode equivalents of background/surface/text above.
  static const Color backgroundDark = Color(0xFF10151A);
  static const Color surfaceDark = Color(0xFF1B2228);
  static const Color textPrimaryDark = Color(0xFFECEFF1);
  static const Color textSecondaryDark = Color(0xFFA0ACB2);
}

/// Theme-aware access to the handful of colours that flip between light and
/// dark mode (background/surface/text). Use `context.textSecondaryColor`
/// etc. instead of a raw `AppColors.textSecondary` wherever the widget
/// should adapt to the current theme.
extension AppThemeColors on BuildContext {
  Color get textPrimaryColor => Theme.of(this).colorScheme.onSurface;
  Color get textSecondaryColor => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;
}

/// Consistent spacing scale, used instead of magic numbers in `EdgeInsets`
/// / `SizedBox` throughout the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Standard corner radius for cards/buttons, kept in one place so the app
/// reads as "rounded and modern" everywhere.
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

/// Builds the app-wide [ThemeData] used by the root `MaterialApp`, for both
/// light and dark mode.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    borderColor: Colors.grey.shade300,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    borderColor: Colors.grey.shade700,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: surface,
      error: AppColors.error,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),

      // Slightly smaller than Material 3's default (12) so 5 tabs —
      // "Suggestions" especially — fit on one line on narrower phones.
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : textSecondary,
          ),
        ),
      ),
    );
  }
}
