import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme.dart';

/// First screen shown on launch: displays the app logo/name briefly, then
/// hands off to [AuthGate], which routes to the Dashboard (logged in) or
/// Onboarding/Login (logged out).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateOnward();
  }

  Future<void> _navigateOnward() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.authGate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.self_improvement,
              size: 88,
              color: Colors.white,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'LifeSync AI',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Your smart routine & wellbeing companion',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
