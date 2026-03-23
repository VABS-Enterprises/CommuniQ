import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:communiq/core/theme/app_theme.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/views/main_navigation_view/screens/main_navigation_view.dart';
import 'package:communiq/views/auth/screens/login_screen.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (using native Android configuration injected via google-services.json)
  await Firebase.initializeApp();

  // TODO: restore before release — check prefs.getBool('isFirstLaunch') != false
  runApp(const MyApp(showOnboarding: true));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CommuniQ',
      theme: AppTheme.darkTheme,
      home: AuthGuard(showOnboarding: showOnboarding),
    );
  }
}

/// A strict guard that listens to Firebase securely. 
/// If the device doesn't have a valid JWT token, it locks them out of the Main App instantly.
class AuthGuard extends StatelessWidget {
  final bool showOnboarding;
  const AuthGuard({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // While Firebase is figuring out if we are logged in or not:
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        // A secure Session Token exists! Grant access to the Main App.
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationView();
        }

        // NO Token found. Lock them out to Login / Onboarding.
        if (showOnboarding) {
          return const WelcomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}