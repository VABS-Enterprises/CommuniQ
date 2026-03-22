import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';

class PositiveFeedbackSection extends StatelessWidget {
  const PositiveFeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What You Did Well',
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
                Icons.star,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  'Great clarity in your speech today!',
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
                Icons.thumb_up,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  'Excellent use of new vocabulary.',
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

