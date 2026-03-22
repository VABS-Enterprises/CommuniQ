import 'package:flutter/material.dart';
import 'views/main_navigation_view/screens/main_navigation_view.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CommuniQ',
      theme: AppTheme.darkTheme,
      home: const MainNavigationView(),
    );
  }
}