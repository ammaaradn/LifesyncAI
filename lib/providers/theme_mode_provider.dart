import 'package:flutter/material.dart';

/// Holds the user's light/dark/system theme choice for this session.
///
/// Deliberately simple - in-memory only, defaulting to [ThemeMode.system]
/// on every app start, rather than persisted to Firestore. That keeps the
/// toggle available even on the pre-login screens (Splash/Onboarding/Login)
/// where there's no signed-in user to store a preference against yet.
class ThemeModeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
