import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';
import 'package:communiq/core/constants/spacing.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isBranch = true,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// True for the four go_router shell branches (Home/Learn/Practise/You),
  /// which track [PlayfulNavBar.currentIndex] and can show as selected.
  /// False for items — like Contest — that simply push a route on top of
  /// the current tab instead of switching branches, so they never light up.
  final bool isBranch;
}

/// The app's bottom navigation: a floating pill with a hard shadow.
///
/// Icon-only — the selected tab sits in a tinted lozenge and its icon
/// switches to the filled/active glyph, so the current location is legible
/// from the icon and colour alone, without a label crowding the bar.
class PlayfulNavBar extends StatelessWidget {
  const PlayfulNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const destinations = [
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavDestination(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Learn',
    ),
    NavDestination(
      icon: Icons.mic_none_rounded,
      activeIcon: Icons.mic_rounded,
      label: 'Practise',
    ),
    NavDestination(
      icon: Icons.emoji_events_outlined,
      activeIcon: Icons.emoji_events_rounded,
      label: 'Contest',
      isBranch: false,
    ),
    NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];

  /// Maps a position in [destinations] to its go_router shell branch index,
  /// skipping non-branch entries (Contest). Only meaningful when
  /// `destinations[destinationIndex].isBranch` is true.
  static int branchIndexFor(int destinationIndex) {
    var branch = -1;
    for (var i = 0; i <= destinationIndex; i++) {
      if (destinations[i].isBranch) branch++;
    }
    return branch;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.pillRadius,
            border: Border.all(color: AppColors.outline, width: 2),
            boxShadow: AppShadow.lifted(y: 4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < destinations.length; i++)
                _NavItem(
                  destination: destinations[i],
                  selected: destinations[i].isBranch &&
                      branchIndexFor(i) == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tint = AppColors.brand;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.settle,
          curve: AppMotion.pop,
          width: 50,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    tint.withValues(alpha: 0.14),
                    AppColors.surface,
                  )
                : AppColors.transparent,
            borderRadius: AppRadius.pillRadius,
          ),
          // A small pop on selection makes the tab change feel physical.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: selected ? 1.12 : 1),
            duration: AppMotion.spring,
            curve: AppMotion.springCurve,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 25,
              color: selected ? tint : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
