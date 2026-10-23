import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';

/// A thick, rounded progress track — XP bars, level completion, session
/// progress. Animates to each new value rather than jumping, so earned
/// progress is visible as it lands.
class ChunkyProgressBar extends StatelessWidget {
  const ChunkyProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 16,
    this.showLabel = false,
    this.label,
    this.animate = true,
  });

  /// 0.0–1.0. Values outside are clamped.
  final double value;

  final Color? color;
  final double height;

  /// Renders the percentage (or [label]) inline above the track.
  final bool showLabel;
  final String? label;

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? AppColors.success;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    // A FractionallySizedBox rather than a LayoutBuilder: LayoutBuilder
    // cannot report intrinsic dimensions, so a bar inside an IntrinsicHeight
    // (the home stats card) threw during layout and the card never painted.
    final track = Container(
      // The track always spans its parent; only the fill is fractional.
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgSunk,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: animate ? AppMotion.settle : Duration.zero,
        curve: AppMotion.ease,
        builder: (context, v, _) {
          // Below a sliver of a percent the rounded cap renders as a
          // splinter; hide it so 0% reads as genuinely empty.
          if (v < 0.005) return const SizedBox.shrink();
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(
              height: height - 4,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(height),
              ),
              // Inner highlight — reads as a glossy capsule rather than a
              // flat block.
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.88,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2.5),
                    height: (height - 4) * 0.24,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!showLabel) return track;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label ?? '${(clamped * 100).round()}%',
            style: AppTextStyles.labelSmall.copyWith(color: fill),
          ),
        ),
        track,
      ],
    );
  }
}
