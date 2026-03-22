import 'package:flutter/material.dart';

import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Evening, Alex',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Unlock your communication potential',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.s8),
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}
