import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/models/user_profile.dart';

class ProgressCard extends StatelessWidget {
  final UserProfile? profile;
  const ProgressCard({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    // Roleplay: 8/11 sessions
    const int roleplaySessions = 8;
    const int roleplayTotal = 11;
    const double roleplayProgress = roleplaySessions / roleplayTotal;

    // Learning: 3/7 modules
    const int learningModules = 3;
    const int learningTotal = 7;
    const double learningProgress = learningModules / learningTotal;

    final streakLabel = (profile?.streak ?? 0) == 0
        ? '🔥 No streak yet'
        : '🔥 ${profile!.streak} day streak';
    final xpLabel = profile == null
        ? 'Next level: — XP'
        : profile!.level >= 5
            ? 'Max level reached!'
            : 'Next level: ${profile!.xpToNextLevel} XP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppGlow.mixedGlow(blurRadius: 16, spreadRadius: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            'Keep the momentum going',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CircularStat(
                label: 'Roleplay',
                progress: roleplayProgress,
                progressText:
                    '${(roleplayProgress * 100).round()}%',
                subLabel: '$roleplaySessions / $roleplayTotal sessions',
              ),
              Container(
                  width: 1, height: 70, color: AppColors.border),
              _CircularStat(
                label: 'Learning',
                progress: learningProgress,
                progressText:
                    '${(learningProgress * 100).round()}%',
                subLabel: '$learningModules / $learningTotal modules',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  streakLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  xpLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularStat extends StatelessWidget {
  final String label;
  final double progress;
  final String progressText;
  final String subLabel;

  const _CircularStat({
    required this.label,
    required this.progress,
    required this.progressText,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 82,
          height: 82,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 7,
                backgroundColor: const Color(0xFF1F2937),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  progressText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subLabel,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
