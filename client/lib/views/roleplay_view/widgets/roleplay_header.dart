import 'package:flutter/material.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/core/constants/app_colors.dart';

class RoleplayHeader extends StatelessWidget {
  const RoleplayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNIQ HUB',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Practice real-life\nconversations',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
        ),
      ],
    );
  }
}
