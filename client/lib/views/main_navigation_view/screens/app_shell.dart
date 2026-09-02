import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communiq/core/routes/app_routes.dart';
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
    final destination = PlayfulNavBar.destinations[index];

    // Contest isn't a shell branch — it's a full-screen route pushed on top
    // of whichever tab is currently open, same as the "Enter a contest" card
    // on Home. It never becomes the "selected" tab.
    if (!destination.isBranch) {
      context.push(AppRoutes.contest);
      return;
    }

    // Tapping the active tab pops that branch back to its root, matching the
    // platform convention.
    final branchIndex = PlayfulNavBar.branchIndexFor(index);
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
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
