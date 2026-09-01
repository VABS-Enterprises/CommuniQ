import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';

/// Compact "earned value" chip: streak, XP, coins, rank.
///
/// The number animates when it changes so a reward is noticed rather than
/// silently swapped in.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    this.color,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;

  /// Rendered verbatim — pass `'1,204'` or `'12'`. Numeric strings animate.
  final String value;

  final Color? color;
  final VoidCallback? onTap;

  /// Tighter padding for dense rows like an app-bar cluster.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.sun;

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 18, color: tint),
          SizedBox(width: compact ? 5 : 7),
          AnimatedSwitcher(
            duration: AppMotion.settle,
            switchInCurve: AppMotion.pop,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: AppTextStyles.numeralSmall.copyWith(
                fontSize: compact ? 13 : 15,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}
