import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            Text(
              'View All',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        _buildActivityRow(context, 'Self Introduction', 'Roleplay', '75%'),
        _buildActivityRow(context, 'HR Interview', 'Practice', '82%'),
        _buildActivityRow(context, 'Pitch presentation', 'Learn', '90%'),
      ],
    );
  }

  Widget _buildActivityRow(
      BuildContext context, String title, String type, String score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        type,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'Score: $score',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
