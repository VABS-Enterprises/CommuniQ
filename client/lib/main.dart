import 'package:flutter/material.dart';

import 'package:communiq/core/theme/app_theme.dart';
import 'package:communiq/views/main_navigation_view/screens/main_navigation_view.dart';
import 'package:communiq/views/onboarding/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: showOnboarding
          ? const WelcomeScreen()
          : const MainNavigationView(),
    );
  }
}