import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class CustomProgressBar extends StatelessWidget {
  final double progress; // Value from 0.0 to 1.0
  final double height;
  final double? width;

  const CustomProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface, // Used to be AppColors.surface
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: maxWidth * progress.clamp(0.0, 1.0),
              height: height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

