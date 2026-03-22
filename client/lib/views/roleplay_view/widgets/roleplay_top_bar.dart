import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class RoleplayTopBar extends StatelessWidget {
  const RoleplayTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.menu, color: AppColors.primary, size: 28),
        Text(
          'Roleplay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.bold,
              ),
        ),
        const Icon(Icons.filter_list, color: AppColors.primary, size: 28),
      ],
    );
  }
}
