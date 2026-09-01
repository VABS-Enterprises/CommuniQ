import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';

/// The app's ambient page background: the cream ground plus a few large, very
/// soft colour blobs.
///
/// Replaces the old starfield/"sky campus" backdrop, which was built for the
/// dark theme. Blobs are deliberately low-contrast — they should register as
/// warmth, never as shapes competing with content.
class PlayfulBackground extends StatelessWidget {
  const PlayfulBackground({
    super.key,
    required this.child,
    this.seed = 0,
    this.intensity = 1.0,
  });

  final Widget child;

  /// Varies the blob layout per screen so backgrounds aren't identical.
  final int seed;

  /// Scales blob opacity. Drop it on dense screens.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BlobPainter(seed: seed, intensity: intensity),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.seed, required this.intensity});

  final int seed;
  final double intensity;

  static const _palette = [
    AppColors.coral,
    AppColors.sun,
    AppColors.teal,
    AppColors.grape,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed * 7919 + 13);

    for (var i = 0; i < 4; i++) {
      final color = _palette[(i + seed) % _palette.length];
      final radius = size.width * (0.32 + rnd.nextDouble() * 0.26);
      final center = Offset(
        size.width * (rnd.nextDouble() * 1.2 - 0.1),
        size.height * (rnd.nextDouble() * 1.05 - 0.05),
      );

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.055 * intensity)
          // A wide blur is what keeps these reading as light rather than shapes.
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.seed != seed || old.intensity != intensity;
}
