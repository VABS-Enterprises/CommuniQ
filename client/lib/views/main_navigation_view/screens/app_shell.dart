import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/views/main_navigation_view/widgets/playful_nav_bar.dart';

/// Hosts the four main tabs.
///
/// Backed by go_router's [StatefulNavigationShell], which keeps a separate
/// navigator (and therefore scroll position and state) per tab — the same
/// property the previous `IndexedStack` provided, but now with real routes, so
/// each tab is addressable and the back stack behaves.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // Flush onboarding answers that were saved locally but never reached the
    // server (offline during sign-up, or a previous run was killed).
    OnboardingService.syncPendingToServer();
  }

  void _onTap(int index) {
    // Tapping the active tab pops that branch back to its root, matching the
    // platform convention.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The nav bar floats over content, so the body extends behind it.
      // Scrollables inside each tab pad their bottom by
      // AppSpacing.navClearance to compensate.
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: PlayfulNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
