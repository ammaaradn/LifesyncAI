import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/main_shell.dart';
import '../screens/onboarding_screen.dart';

/// Decides what the user sees right after Splash:
/// - already logged in  -> straight to the main bottom-nav shell
/// - logged out         -> Onboarding, which leads into Login/Signup
///
/// Listens to [AuthService.authStateChanges] (exposed as a `StreamProvider`
/// in `main.dart`), so logging in/out anywhere in the app updates this
/// automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    return user != null ? const MainShell() : const OnboardingScreen();
  }
}
