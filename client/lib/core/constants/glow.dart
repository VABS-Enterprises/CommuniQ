import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class AppGlow {
  static List<BoxShadow> cyanGlow({double blurRadius = 16.0, double spreadRadius = 2.0}) {
    return [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.15),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  static List<BoxShadow> magentaGlow({double blurRadius = 16.0, double spreadRadius = 2.0}) {
    return [
      BoxShadow(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
      ),
    ];
  }

  // Combined glow for special elements
  static List<BoxShadow> mixedGlow({double blurRadius = 16.0, double spreadRadius = 2.0}) {
    return [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.1),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
