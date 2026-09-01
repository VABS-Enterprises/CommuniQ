import 'package:flutter/material.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/spacing.dart';

/// A selectable row for choice screens — goals, skill level, speaking style,
/// difficulty, MCQ answers.
///
/// All 14 onboarding screens previously hand-rolled a private `_OptionCard`
/// with slightly different padding, radius and selected-state treatment each
/// time. This is the single version.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.emoji,
    this.accent,
    this.trailing,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;

  /// Leading icon. Ignored when [emoji] is set.
  final IconData? icon;

  /// Leading emoji, for warmer/lighter choices where an icon feels clinical.
  final String? emoji;

  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  /// Replaces the default check indicator.
  final Widget? trailing;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.coral;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ChunkyCard(
        onTap: enabled ? onTap : null,
        selected: selected,
        accent: tint,
        margin: const EdgeInsets.only(bottom: AppSpacing.item),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.s14),
            ] else if (icon != null) ...[
              IconTile(icon: icon!, color: tint, size: 42),
              const SizedBox(width: AppSpacing.s14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            trailing ?? _Check(selected: selected, tint: tint),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.tint});

  final bool selected;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.pop,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? tint : AppColors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? tint : AppColors.outline,
          width: 2.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.inkOnDark)
          : null,
    );
  }
}
