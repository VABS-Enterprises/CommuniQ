import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/gradient_button.dart';
import 'package:communiq/common_widgets/progress_bar.dart';
import 'package:communiq/common_widgets/glowing_icon.dart';

class ContinuePracticeCard extends StatelessWidget {
  const ContinuePracticeCard({super.key});

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Practice',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Continue Introduction Hub',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
              const GlowingIcon(
                icon: Icons.mic,
                glowColor: GlowColor.cyan,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          const CustomProgressBar(progress: 0.45),
          const SizedBox(height: AppSpacing.s24),
          GradientButton(
            text: 'Resume',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
