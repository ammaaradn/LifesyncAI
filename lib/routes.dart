import 'package:flutter/material.dart';

import 'widgets/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/profile_screen.dart';

/// Central list of named routes, so screens never hardcode route strings.
///
/// Planner/Health Tracker/Insights/Smart Suggestions aren't routes - they're
/// tabs inside [MainShell] (see `dashboard`), reached via its bottom nav
/// instead of Navigator.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String authGate = '/auth-gate';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    authGate: (_) => const AuthGate(),
    onboarding: (_) => const OnboardingScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    dashboard: (_) => const MainShell(),
    profile: (_) => const ProfileScreen(),
  };
}
