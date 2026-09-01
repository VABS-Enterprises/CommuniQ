import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:communiq/core/theme/app_theme.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/routes/app_router.dart';

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

  runApp(MyApp());
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
      runApp(MyApp());
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
                        color: AppColors.brand)
                    : TextButton(
                        onPressed: _retry,
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                              color: AppColors.brand,
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
  MyApp({super.key});

  final GoRouter _router = createRouter(gallery: _kGallery);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CommuniQ',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
