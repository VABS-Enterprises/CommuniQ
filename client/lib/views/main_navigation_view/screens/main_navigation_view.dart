import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/views/home_view/screens/home_view.dart';
import 'package:communiq/views/home_view/widgets/quick_actions_row.dart';
import 'package:communiq/views/learning_view/screens/learning_view.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_view.dart';
import '../widgets/floating_nav_bar.dart';

const _kTabNames = ['Home', 'Learning', 'Roleplay'];

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 [MainNav] Main navigation loaded — starting on ${_kTabNames[_currentIndex]}');
    // Flush any onboarding data that was saved locally but not yet synced
    // (e.g. server was unreachable during sign-up, or this is a retry session).
    OnboardingService.syncPendingToServer();
  }

  void switchTab(int index) {
    if (!mounted || index == _currentIndex) return;
    debugPrint('🏠 [MainNav] Tab switch: ${_kTabNames[_currentIndex]} → ${_kTabNames[index]}');
    setState(() => _currentIndex = index);
  }

  late final List<Widget> _screens = [
    const HomeView(),
    const LearningView(),
    const RoleplayView(),
  ];

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SwitchToLearningTabNotification>(
      onNotification: (_) {
        switchTab(1);
        return true;
      },
      child: NotificationListener<SwitchToRoleplayTabNotification>(
        onNotification: (_) {
          switchTab(2);
          return true;
        },
        child: Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FloatingNavBar(
                  currentIndex: _currentIndex,
                  onTabSelected: switchTab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
