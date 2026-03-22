import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/progress_bar.dart';

class ContestDashboardRow extends StatelessWidget {
  const ContestDashboardRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Contest',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Weekly Challenge',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                const CustomProgressBar(progress: 0.45),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Rank: Silver II',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          flex: 4,
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '78%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Your Score',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      'Improving',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

