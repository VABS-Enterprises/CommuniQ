 import 'package:flutter/material.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/glow.dart';

/// The app's one canonical "elevated content card": AppColors.surface fill,
/// a visible glassBorder edge, AppRadius.cards corners, and an optional glow.
/// Screens should reach for this instead of hand-rolling Container+BoxDecoration
/// with their own radius/border/shadow combination.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double borderAlpha;
  final bool glow;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.cards,
    this.borderAlpha = 0.4,
    this.glow = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: borderAlpha),
          width: 1.0,
        ),
        boxShadow: glow
            ? AppGlow.cyanGlow(blurRadius: 16, spreadRadius: 1)
                .map((s) => glowColor != null ? BoxShadow(
                      color: glowColor!.withValues(alpha: 0.15),
                      blurRadius: s.blurRadius,
                      spreadRadius: s.spreadRadius,
                    ) : s)
                .toList()
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
