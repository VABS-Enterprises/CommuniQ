import 'package:flutter/material.dart';

import 'package:communiq/common_widgets/chunky_card.dart';
import 'package:communiq/common_widgets/icon_tile.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/data/scenario_presets.dart';

/// One selectable scenario row. Used by both the Practise tab and the full
/// "All scenarios" list so the two can't drift apart again.
class ScenarioTile extends StatelessWidget {
  const ScenarioTile({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
    this.showArt = true,
  });

  final ScenarioPreset preset;
  final bool selected;
  final VoidCallback onTap;

  /// Shows the scenario illustration instead of a plain icon tile.
  final bool showArt;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      selected: selected,
      accent: preset.color,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        children: [
          if (showArt)
            _Art(asset: preset.image, color: preset.color)
          else
            IconTile(icon: preset.icon, color: preset.color, size: 52),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(preset.title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  preset.subtitle,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.pop,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? preset.color : AppColors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? preset.color : AppColors.outline,
                width: 2.5,
              ),
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.chevron_right_rounded,
              size: 17,
              color: selected ? AppColors.inkOnDark : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scenario illustrations are dark, high-contrast art. They get their own
/// dark frame so they read as artwork on the cream card rather than a
/// mis-styled panel.
class _Art extends StatelessWidget {
  const _Art({required this.asset, required this.color});

  final String asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: AppRadius.chipRadius,
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.theater_comedy_rounded,
          color: color,
          size: 26,
        ),
      ),
    );
  }
}
