import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';

class PerformanceFeedbackSection extends StatelessWidget {
  const PerformanceFeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Performance',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  'Great clarity in answers',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  'Improve confidence slightly',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              const Icon(
                Icons.record_voice_over,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  'Strong vocabulary usage',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

