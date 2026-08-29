import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/weather_provider.dart';
import 'routes.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/weather_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LifeSyncApp());
}

class LifeSyncApp extends StatelessWidget {
  const LifeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<WeatherService>(create: (_) => WeatherService()),
        ChangeNotifierProvider<ThemeModeProvider>(
          create: (_) => ThemeModeProvider(),
        ),
        ChangeNotifierProvider<WeatherProvider>(
          create: (context) => WeatherProvider(
            locationService: context.read<LocationService>(),
            weatherService: context.read<WeatherService>(),
          )..load(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        // Recreated whenever the signed-in user changes, so every screen
        // reading FirestoreService automatically switches to the right
        // user's data (and to null right after logout).
        ProxyProvider<User?, FirestoreService?>(
          update: (_, user, _) =>
              user != null ? FirestoreService(uid: user.uid) : null,
        ),
      ],
      // A Builder so `context` below can see the providers just installed
      // above - the outer `context` (this widget's own) sits above them.
      child: Builder(
        builder: (context) {
          final themeMode = context.watch<ThemeModeProvider>().themeMode;
          return MaterialApp(
            title: 'LifeSync AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
