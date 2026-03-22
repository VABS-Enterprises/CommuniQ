import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';

class TodaysProgressCard extends StatelessWidget {
  const TodaysProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Progress",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            "Keep the momentum going",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularProgress(context, 'Social Skill', 0.60, '60%'),
              _buildCircularProgress(context, 'Daily Goal', 0.30, '30%'),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s12,
              horizontal: AppSpacing.s16,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      '10 Day Streak',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Text(
                  'Next Reward: 250 XP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCircularProgress(
    BuildContext context,
    String label,
    double progress,
    String progressText,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: AppColors.background,
                color: AppColors.primary,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  progressText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
