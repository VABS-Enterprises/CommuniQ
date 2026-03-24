import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/models/user_profile.dart';

class TodaysProgressCard extends StatelessWidget {
  /// Pass the loaded profile to show real data. While null the card shows
  /// skeleton/placeholder values so the layout never jumps.
  final UserProfile? profile;

  const TodaysProgressCard({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    final xpProgress = profile?.xpProgress ?? 0.0;
    final xpProgressPct = '${(xpProgress * 100).round()}%';

    final streakProgress = profile?.streakProgress ?? 0.0;
    final streakDays = profile?.streak ?? 0;
    final streakLabel = streakDays == 0
        ? 'No streak yet'
        : streakDays == 1
            ? '1 Day Streak'
            : '$streakDays Days Streak';

    final xpToNext = profile?.xpToNextLevel ?? 0;
    final rewardText = profile == null
        ? '—'
        : profile!.level >= 5
            ? 'Max level reached!'
            : 'Next level: $xpToNext XP away';

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Progress",
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
              _buildCircularProgress(context, 'Level Progress', xpProgress, xpProgressPct),
              _buildCircularProgress(context, 'Streak Goal', streakProgress,
                  '${(streakProgress * 100).round()}%'),
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
              border: Border.all(color: AppColors.border, width: 1),
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
                      streakLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Text(
                  rewardText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
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
