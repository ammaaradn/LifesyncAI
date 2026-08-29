// Basic smoke test: verifies the Splash screen shows the app name and then
// navigates onward after its delay.
//
// This tests SplashScreen in isolation (a bare MaterialApp with a stub
// destination route) rather than the full app, since the real app requires
// a live Firebase connection to boot past the Splash screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifesync_ai/routes.dart';
import 'package:lifesync_ai/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows app name then navigates onward', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.authGate: (_) => const Scaffold(body: Text('next screen')),
        },
        home: const SplashScreen(),
      ),
    );

    expect(find.text('LifeSync AI'), findsOneWidget);
    expect(find.text('Your smart routine & wellbeing companion'), findsOneWidget);

    // Let the splash screen's 2-second navigation timer fire.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('next screen'), findsOneWidget);
  });
}
