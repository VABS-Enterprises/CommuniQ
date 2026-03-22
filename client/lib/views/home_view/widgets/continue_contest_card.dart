import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/common_widgets/progress_bar.dart';
import 'package:communiq/common_widgets/glowing_icon.dart';

class ContinueContestCard extends StatelessWidget {
  const ContinueContestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contest',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Resume your current challenge',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              const GlowingIcon(
                icon: Icons.emoji_events,
                glowColor: GlowColor.cyan,
                size: 24,
                color: AppColors.white,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          const CustomProgressBar(progress: 0.65),
          const SizedBox(height: AppSpacing.s24),
          GradientButton(
            text: 'Resume Contest',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
