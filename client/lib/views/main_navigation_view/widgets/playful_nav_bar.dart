import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';
import 'package:communiq/core/constants/spacing.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The app's bottom navigation: a floating pill with a hard shadow.
///
/// The selected tab expands into a tinted lozenge and reveals its label, so
/// the current location is legible without relying on colour alone.
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
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];

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
                  selected: currentIndex == i,
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
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 16),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    tint.withValues(alpha: 0.14),
                    AppColors.surface,
                  )
                : AppColors.transparent,
            borderRadius: AppRadius.pillRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A small pop on selection makes the tab change feel physical.
              TweenAnimationBuilder<double>(
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
              // The label only exists for the selected tab; animating its
              // width keeps the other tabs from jumping as it appears.
              ClipRect(
                child: AnimatedAlign(
                  duration: AppMotion.settle,
                  curve: AppMotion.ease,
                  alignment: Alignment.centerLeft,
                  widthFactor: selected ? 1 : 0,
                  child: AnimatedOpacity(
                    duration: AppMotion.quick,
                    opacity: selected ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        style: AppTextStyles.labelMedium.copyWith(color: tint),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
