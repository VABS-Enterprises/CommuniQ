import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';

/// Hand-rolled confetti burst — no package dependency.
///
/// Wrap a screen in it and call `ConfettiOverlay.of(context).burst()` (or drive
/// [play]) at a reward moment: session complete, level up, new best score.
/// Particles are simple physics — initial velocity, gravity, drag, spin — which
/// is enough to read as celebratory and costs one `CustomPaint`.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.child,
    this.play = false,
    this.particleCount = 70,
  });

  final Widget child;

  /// Flip false→true to fire a burst.
  final bool play;

  final int particleCount;

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();

  static ConfettiOverlayState? of(BuildContext context) =>
      context.findAncestorStateOfType<ConfettiOverlayState>();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    if (widget.play) burst();
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.play && widget.play) burst();
  }

  /// Fires a burst. Safe to call repeatedly — it restarts rather than stacking.
  void burst() {
    final rnd = math.Random();
    _particles
      ..clear()
      ..addAll(
        List.generate(widget.particleCount, (_) {
          // Launch upward and outward from just below the top third.
          final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 1.9;
          final speed = 0.55 + rnd.nextDouble() * 0.85;
          return _Particle(
            x: 0.5 + (rnd.nextDouble() - 0.5) * 0.35,
            y: 0.42 + (rnd.nextDouble() - 0.5) * 0.08,
            vx: math.cos(angle) * speed,
            vy: math.sin(angle) * speed,
            color: _palette[rnd.nextInt(_palette.length)],
            size: 6 + rnd.nextDouble() * 7,
            spin: (rnd.nextDouble() - 0.5) * 12,
            rotation: rnd.nextDouble() * math.pi,
            square: rnd.nextBool(),
          );
        }),
      );
    _c
      ..reset()
      ..forward();
  }

  static const _palette = [
    AppColors.brand,
    AppColors.sun,
    AppColors.brand,
    AppColors.brand,
    AppColors.success,
    AppColors.brand,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    t: _c.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.rotation,
    required this.square,
  });

  /// Start position and velocity, both in fractions of the canvas.
  final double x, y, vx, vy;
  final Color color;
  final double size;
  final double spin;
  final double rotation;
  final bool square;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;

    const gravity = 1.15;
    const drag = 0.72;

    for (final p in particles) {
      // Horizontal motion decays; vertical accelerates downward.
      final dx = p.vx * t * drag;
      final dy = p.vy * t + 0.5 * gravity * t * t;

      final px = (p.x + dx) * size.width;
      final py = (p.y + dy) * size.height;

      if (py > size.height + 40) continue;

      // Hold full opacity for most of the flight, then fade out at the end.
      final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + p.spin * t);

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      if (p.square) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.42, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
