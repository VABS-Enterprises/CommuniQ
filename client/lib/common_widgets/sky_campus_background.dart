import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';

class SkyCampusBackground extends StatelessWidget {
  final Widget child;

  const SkyCampusBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1 â€” Base Linear Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background, // #070014
                AppColors.background, // #0E0324
                AppColors.background, // #160735
              ],
            ),
          ),
        ),

        // Layer 2 â€” Soft Radial Glow
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2), // Centered slightly above the middle
              radius: 1.2,
              colors: [
                AppColors.primary.withValues(alpha: 0.08), // 8% opacity #5B2EFF
                AppColors.primary.withValues(alpha: 0.0), // Fade to transparent
              ],
            ),
          ),
        ),

        // Layer 3 â€” Edge Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.20), // 20% opacity #070014 at edges
              ],
              stops: const [0.5, 1.0], // Center remains transparent
            ),
          ),
        ),

        // Layer 4 â€” Subtle Light Diffusion
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.8, // Large radius for subtle ambient light
              colors: [
                AppColors.primary.withValues(alpha: 0.04), // 4% opacity #5B2EFF
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),

        // SafeArea child content
        SafeArea(
          child: child,
        ),
      ],
    );
  }
}

