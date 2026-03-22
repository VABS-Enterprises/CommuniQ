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
      alignment: Alignment.center, // compact pill centered
      child: GlassCard(
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.navigationRadius,
            border: Border.all(color: AppColors.border, width: 1.0),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.navigationRadius,
            child: Container(
              color: AppColors.border,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              child: Row(
                mainAxisSize: MainAxisSize.min, // shrink to content
                children: [
                  _NavBarItem(
                    icon: Icons.home,
                    isSelected: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                  _NavBarItem(
                    icon: Icons.menu_book,
                    isSelected: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                    iconSize: 26,
                  ),
                  _NavBarItem(
                    icon: Icons.mic,
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
    final Color iconColor =
        isSelected ? AppColors.primary : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()..scale(isSelected ? 0.97 : 1.0),
        child: isSelected
            ? GlowingIcon(
                icon: icon,
                color: iconColor,
                glowColor: GlowColor.cyan,
                size: iconSize,
              )
            : Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}
