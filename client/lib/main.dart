import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:communiq/core/theme/app_theme.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/auth_service.dart';
import 'package:communiq/views/main_navigation_view/screens/main_navigation_view.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';
import 'package:communiq/views/onboarding/screens/splash_screen.dart';
import 'package:communiq/views/dev/component_gallery.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  bool firebaseOk = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp();
    firebaseOk = true;
  } catch (e) {
    firebaseError = e.toString();
    debugPrint('[main] Firebase initialization failed: $e');
  }

  if (!firebaseOk) {
    runApp(_FirebaseErrorApp(error: firebaseError ?? 'Unknown error'));
    FlutterNativeSplash.remove();
    return;
  }

  runApp(const MyApp());
  FlutterNativeSplash.remove();
}

/// Shown only when Firebase itself fails to initialize (rare, fatal).
class _FirebaseErrorApp extends StatefulWidget {
  final String error;
  const _FirebaseErrorApp({required this.error});

  @override
  State<_FirebaseErrorApp> createState() => _FirebaseErrorAppState();
}

class _FirebaseErrorAppState extends State<_FirebaseErrorApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await Firebase.initializeApp();
      runApp(const MyApp());
    } catch (_) {
      setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 56),
                const SizedBox(height: 20),
                const Text(
                  'App failed to start',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'There was a problem connecting to our services. '
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.inkMuted, fontSize: 14),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 28),
                _retrying
                    ? const CircularProgressIndicator(
                        color: AppColors.coral)
                    : TextButton(
                        onPressed: _retry,
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                              color: AppColors.coral,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Launches straight into the design-system gallery instead of the app:
///   flutter run --dart-define=GALLERY=true
/// Debug affordance only — no user-facing route reaches it.
const _kGallery = bool.fromEnvironment('GALLERY');

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CommuniQ',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: _kGallery ? const ComponentGallery() : const SplashScreen(),
    );
  }
}

/// Guards the app with Firebase auth state. Unauthenticated users are sent to
/// the welcome/onboarding screen. Authenticated users go straight to the main app.
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  int _streamKey = 0;

  void _retry() => setState(() => _streamKey++);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      key: ValueKey(_streamKey),
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        debugPrint('[AuthGuard] snapshot: state=${snapshot.connectionState}, hasData=${snapshot.hasData}, user=${snapshot.data?.uid}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
                child: CircularProgressIndicator(
                    color: AppColors.coral)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppColors.inkSoft, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Connection error',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We could not reach authentication services.\n'
                    'Please check your connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.inkMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _retry,
                    child: const Text('Retry',
                        style: TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                  TextButton(
                    onPressed: () => AuthService.signOut(),
                    child: const Text('Sign Out',
                        style:
                            TextStyle(color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          debugPrint('[AuthGuard] User detected! Returning MainNavigationView');
          return const MainNavigationView();
        }

        debugPrint('[AuthGuard] No user. Returning WelcomeScreen');
        return const WelcomeScreen();
      },
    );
  }
}
