import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

enum GlowColor { cyan, magenta, mixed } // To maintain API compatibility

class GlowingIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final GlowColor glowColor;
  final Color? color;

  const GlowingIcon({
    super.key,
    required this.icon,
    this.size = 24.0,
    this.glowColor = GlowColor.cyan, // Ignored now
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: size * 0.5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size,
        color: iconColor,
      ),
    );
  }
}
