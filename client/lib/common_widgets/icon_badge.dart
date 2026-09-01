import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/radius.dart';

/// The app's "icon in a colored box" pattern — a small icon centered in a
/// filled, rounded (or circular) container. This exact shape repeats across
/// list tiles, feature rows, and section headers throughout the app, each
/// previously hand-rolled with its own size/radius combination. Use this
/// instead so the same visual role always looks the same.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color? iconColor;
  final double borderRadius;
  final bool circle;

  const IconBadge({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 17,
    this.color = AppColors.primary,
    this.iconColor,
    this.borderRadius = AppRadius.chips,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: iconColor ?? AppColors.white, size: iconSize),
    );
  }
}
