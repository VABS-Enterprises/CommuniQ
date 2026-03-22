import 'package:flutter/material.dart';

import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/glowing_icon.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s24),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GlassCard(
        height: 72,
        // The GlassCard already manages border radius (to AppRadius.cards instead of navigation), 
        // border gradient (to glassCardBorder), and background color.
        // But we need to override color to midnightPurple and radius to navigationRadius.
        // Since GlassCard uses predetermined values, we will build the custom decoration here.
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.navigationRadius,
            border: Border.all(
              color: AppColors.border,
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.navigationRadius,
            child: Container(
              color: AppColors.border, // Glass white (8% opacity) overlaid
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavBarItem(
                    icon: Icons.home,
                    isSelected: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                  _NavBarItem(
                    icon: Icons.menu_book, // Learning
                    isSelected: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                    iconSize: 32, // Slightly larger icon size for Learning
                  ),
                  _NavBarItem(
                    icon: Icons.mic, // Roleplay
                    isSelected: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double iconSize;

  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    // Colors
    final Color iconColor =
        isSelected ? AppColors.primary : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.s8),
        // Scale down to 0.97 if selected using transform
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()..scale(isSelected ? 0.97 : 1.0),
        child: isSelected
            ? GlowingIcon(
                icon: icon,
                color: iconColor,
                glowColor: GlowColor.cyan,
                size: iconSize,
              )
            : Icon(
                icon,
                color: iconColor,
                size: iconSize,
              ),
      ),
    );
  }
}

