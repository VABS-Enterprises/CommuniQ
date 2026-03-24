import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class RoleplayTopBar extends StatelessWidget {
  const RoleplayTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Roleplay',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
