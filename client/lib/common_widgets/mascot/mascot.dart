import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/motion.dart';

/// What Whisperwing is doing. Drives eye shape, brow, beak, wing pose and the
/// idle animation, so a screen sets a mood rather than composing a pose.
enum MascotMood {
  /// Resting. Slow bob, occasional blink.
  idle,

  /// Pleased — curved "happy" eyes, small bounce.
  happy,

  /// Considering. Looks up and away, one brow raised.
  thinking,

  /// Actively listening during a live session — wide eyes, leaning in.
  listening,

  /// Big win: level up, new best score. Wings up, eyes shut, fast bounce.
  celebrating,

  /// Gentle nudge after a miss — a wink.
  encouraging,

  /// Something went wrong. Droopy eyes, looking down.
  sad,
}

/// Whisperwing, CommuniQ's owl — drawn entirely in code.
///
/// Deliberately **not** an image asset: it re-colours with the theme, scales to
/// any size without a 2x/3x set, animates per-mood, and costs nothing to ship.
/// The two legacy hummingbird PNGs it replaces were ~1.6 MB with a dark
/// background baked in, so they could not sit on the light ground at all.
///
/// For the two moments where the bundled Lottie files already say it better,
/// prefer those instead: `assets/icons/Thumbs Up.json` for a celebration
/// payoff, `assets/icons/Mic.json` for the live-recording indicator.
class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.mood = MascotMood.idle,
    this.size = 140,
    this.color,
    this.animate = true,
  });

  final MascotMood mood;
  final double size;

  /// Body colour. Defaults to [AppColors.brand].
  final Color? color;

  /// Set false for a still pose (list rows, dense layouts).
  final bool animate;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _blink;

  /// Drives the mood-to-mood morph so a mood change eases rather than snaps.
  late final AnimationController _moodShift;

  MascotMood _from = MascotMood.idle;

  /// Held so dispose can cancel it — a bare Future.delayed would keep firing
  /// after the widget is gone.
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _from = widget.mood;

    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _moodShift = AnimationController(
      vsync: this,
      duration: AppMotion.spring,
      value: 1,
    );

    if (widget.animate) {
      _idle.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  /// Blinks on an irregular cadence — a fixed interval reads mechanical.
  void _scheduleBlink() {
    if (!mounted || !widget.animate) return;
    _blinkTimer?.cancel();
    final ms = 1800 + math.Random().nextInt(2600);
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
      if (!mounted || !widget.animate) return;
      // Eyes are already shut in these moods; blinking would be invisible.
      if (widget.mood != MascotMood.celebrating &&
          widget.mood != MascotMood.happy) {
        await _blink.forward();
        if (!mounted) return;
        await _blink.reverse();
        if (!mounted) return;
      }
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);

    if (old.mood != widget.mood) {
      _from = old.mood;
      _moodShift
        ..reset()
        ..forward();
    }

    if (old.animate != widget.animate) {
      if (widget.animate) {
        _idle.repeat(reverse: true);
        _scheduleBlink();
      } else {
        _idle.stop();
        _blinkTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _moodShift.dispose();
    super.dispose();
  }

  /// Celebrating and listening want a livelier idle than a slow bob.
  double _bobAmplitude(MascotMood m) => switch (m) {
        MascotMood.celebrating => 0.055,
        MascotMood.happy => 0.03,
        MascotMood.listening => 0.018,
        MascotMood.sad => 0.008,
        _ => 0.02,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _blink, _moodShift]),
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_idle.value);
          final bob = (t - 0.5) * 2 * _bobAmplitude(widget.mood);

          return CustomPaint(
            painter: _MascotPainter(
              from: _from,
              to: widget.mood,
              morph: Curves.easeOutCubic.transform(_moodShift.value),
              bob: bob,
              blink: _blink.value,
              body: widget.color ?? AppColors.brand,
            ),
          );
        },
      ),
    );
  }
}

/// Per-mood pose values, interpolated between moods so transitions are smooth.
class _Pose {
  const _Pose({
    required this.eyeOpen,
    required this.eyeCurve,
    required this.pupilX,
    required this.pupilY,
    required this.browAngle,
    required this.wingLift,
    required this.leanY,
    required this.beakOpen,
    this.winkRight = 0,
  });

  /// 0 = shut, 1 = fully open.
  final double eyeOpen;

  /// 0 = round eye, 1 = upward "happy" arc.
  final double eyeCurve;

  /// Pupil offset, in units of eye radius.
  final double pupilX;
  final double pupilY;

  /// Radians; positive tilts the inner brow down (concerned/cross).
  final double browAngle;

  /// 0 = wings at rest, 1 = wings raised.
  final double wingLift;

  /// Vertical body offset as a fraction of canvas size.
  final double leanY;

  /// 0 = closed beak, 1 = open.
  final double beakOpen;

  /// Shuts the right eye only.
  final double winkRight;

  static const _Pose idle = _Pose(
    eyeOpen: 1,
    eyeCurve: 0,
    pupilX: 0,
    pupilY: 0,
    browAngle: 0,
    wingLift: 0,
    leanY: 0,
    beakOpen: 0,
  );

  static const _Pose happy = _Pose(
    eyeOpen: 1,
    eyeCurve: 1,
    pupilX: 0,
    pupilY: 0,
    browAngle: 0,
    wingLift: 0.3,
    leanY: -0.01,
    beakOpen: 0.5,
  );

  static const _Pose thinking = _Pose(
    eyeOpen: 0.82,
    eyeCurve: 0,
    pupilX: -0.42,
    pupilY: -0.45,
    browAngle: -0.22,
    wingLift: 0,
    leanY: 0,
    beakOpen: 0,
  );

  static const _Pose listening = _Pose(
    eyeOpen: 1.15,
    eyeCurve: 0,
    pupilX: 0,
    pupilY: 0.08,
    browAngle: -0.18,
    wingLift: 0.12,
    leanY: 0.015,
    beakOpen: 0.15,
  );

  static const _Pose celebrating = _Pose(
    eyeOpen: 1,
    eyeCurve: 1,
    pupilX: 0,
    pupilY: 0,
    browAngle: 0,
    wingLift: 1,
    leanY: -0.03,
    beakOpen: 1,
  );

  static const _Pose encouraging = _Pose(
    eyeOpen: 1,
    eyeCurve: 0,
    pupilX: 0.1,
    pupilY: 0,
    browAngle: 0,
    wingLift: 0.45,
    leanY: 0,
    beakOpen: 0.45,
    winkRight: 1,
  );

  static const _Pose sad = _Pose(
    eyeOpen: 0.55,
    eyeCurve: 0,
    pupilX: 0,
    pupilY: 0.45,
    browAngle: 0.42,
    wingLift: -0.15,
    leanY: 0.025,
    beakOpen: 0,
  );

  static _Pose of(MascotMood m) => switch (m) {
        MascotMood.idle => idle,
        MascotMood.happy => happy,
        MascotMood.thinking => thinking,
        MascotMood.listening => listening,
        MascotMood.celebrating => celebrating,
        MascotMood.encouraging => encouraging,
        MascotMood.sad => sad,
      };

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
        eyeOpen: _l(a.eyeOpen, b.eyeOpen, t),
        eyeCurve: _l(a.eyeCurve, b.eyeCurve, t),
        pupilX: _l(a.pupilX, b.pupilX, t),
        pupilY: _l(a.pupilY, b.pupilY, t),
        browAngle: _l(a.browAngle, b.browAngle, t),
        wingLift: _l(a.wingLift, b.wingLift, t),
        leanY: _l(a.leanY, b.leanY, t),
        beakOpen: _l(a.beakOpen, b.beakOpen, t),
        winkRight: _l(a.winkRight, b.winkRight, t),
      );
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({
    required this.from,
    required this.to,
    required this.morph,
    required this.bob,
    required this.blink,
    required this.body,
  });

  final MascotMood from;
  final MascotMood to;
  final double morph;
  final double bob;
  final double blink;
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pose = _Pose.lerp(_Pose.of(from), _Pose.of(to), morph);

    // Everything is drawn in a normalised square then translated by the idle
    // bob, so poses stay resolution-independent.
    final cx = size.width / 2;
    final dy = (bob + pose.leanY) * s;

    canvas.save();
    canvas.translate(cx, dy);

    final bodyPaint = Paint()..color = body;
    final darkPaint = Paint()..color = AppColors.shadowFor(body);
    final bellyPaint = Paint()
      ..color = Color.lerp(body, AppColors.white, 0.72)!;

    _drawFeet(canvas, s, darkPaint);
    _drawWings(canvas, s, pose, darkPaint);
    _drawBody(canvas, s, bodyPaint, bellyPaint);
    _drawTufts(canvas, s, bodyPaint);
    _drawEyes(canvas, s, pose, darkPaint);
    _drawBrows(canvas, s, pose, darkPaint);
    _drawBeak(canvas, s, pose);

    canvas.restore();
  }

  void _drawBody(Canvas canvas, double s, Paint bodyPaint, Paint bellyPaint) {
    final bodyRect = Rect.fromCenter(
      center: Offset(0, s * 0.53),
      width: s * 0.70,
      height: s * 0.74,
    );
    canvas.drawOval(bodyRect, bodyPaint);

    // Belly patch — an oval clipped to the lower body.
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.66),
        width: s * 0.46,
        height: s * 0.50,
      ),
      bellyPaint,
    );
    canvas.restore();
  }

  void _drawTufts(Canvas canvas, double s, Paint bodyPaint) {
    for (final dir in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(dir * s * 0.10, s * 0.24)
        ..quadraticBezierTo(
          dir * s * 0.30,
          s * 0.05,
          dir * s * 0.31,
          s * 0.20,
        )
        ..quadraticBezierTo(
          dir * s * 0.28,
          s * 0.26,
          dir * s * 0.10,
          s * 0.24,
        )
        ..close();
      canvas.drawPath(path, bodyPaint);
    }
  }

  void _drawWings(Canvas canvas, double s, _Pose pose, Paint darkPaint) {
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      // Pivot at the shoulder, with the wing hanging below it, so raising a
      // wing swings its tip outward rather than lifting the whole shape over
      // the head.
      canvas.translate(dir * s * 0.28, s * 0.44);
      canvas.rotate(dir * -pose.wingLift * 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dir * s * 0.045, s * 0.15),
          width: s * 0.17,
          height: s * 0.34,
        ),
        darkPaint,
      );
      canvas.restore();
    }
  }

  void _drawFeet(Canvas canvas, double s, Paint darkPaint) {
    for (final dir in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(dir * s * 0.13, s * 0.90),
            width: s * 0.13,
            height: s * 0.07,
          ),
          Radius.circular(s * 0.035),
        ),
        darkPaint,
      );
    }
  }

  void _drawEyes(Canvas canvas, double s, _Pose pose, Paint darkPaint) {
    final r = s * 0.155;
    const yc = 0.44;

    for (final dir in [-1.0, 1.0]) {
      final center = Offset(dir * s * 0.165, s * yc);

      // Blink and wink both close the lid; take whichever is more closed.
      final winking = dir > 0 ? pose.winkRight : 0.0;
      final closed = math.max(blink, winking);
      final open = (pose.eyeOpen * (1 - closed)).clamp(0.0, 1.4);

      // A "happy" eye is an upward arc rather than a disc, so past the halfway
      // point of eyeCurve we swap shapes entirely.
      if (pose.eyeCurve > 0.5 && closed < 0.5) {
        final arc = Path();
        final w = r * 0.78;
        arc.moveTo(center.dx - w, center.dy + r * 0.30);
        arc.quadraticBezierTo(
          center.dx,
          center.dy - r * 0.75,
          center.dx + w,
          center.dy + r * 0.30,
        );
        canvas.drawPath(
          arc,
          Paint()
            ..color = darkPaint.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.045
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      // Sclera, squashed vertically by how closed the lid is.
      final h = r * 2 * open;
      if (h <= 0.5) {
        // Fully shut — a simple line reads better than a zero-height oval.
        canvas.drawLine(
          Offset(center.dx - r * 0.62, center.dy),
          Offset(center.dx + r * 0.62, center.dy),
          Paint()
            ..color = darkPaint.color
            ..strokeWidth = s * 0.035
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }

      final eyeRect = Rect.fromCenter(
        center: center,
        width: r * 2,
        height: h,
      );
      canvas.drawOval(eyeRect, Paint()..color = AppColors.white);

      // Pupil, clipped so it can't escape the sclera when looking far off-axis.
      canvas.save();
      canvas.clipPath(Path()..addOval(eyeRect));
      final pupilR = r * 0.52;
      canvas.drawCircle(
        center + Offset(pose.pupilX * r * 0.7, pose.pupilY * r * 0.7),
        pupilR,
        Paint()..color = AppColors.ink,
      );
      // Catchlight — small, offset up-left. Sells it as an eye.
      canvas.drawCircle(
        center +
            Offset(
              pose.pupilX * r * 0.7 - pupilR * 0.34,
              pose.pupilY * r * 0.7 - pupilR * 0.36,
            ),
        pupilR * 0.30,
        Paint()..color = AppColors.white,
      );
      canvas.restore();
    }
  }

  void _drawBrows(Canvas canvas, double s, _Pose pose, Paint darkPaint) {
    if (pose.browAngle.abs() < 0.02) return;

    final paint = Paint()
      ..color = darkPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..strokeCap = StrokeCap.round;

    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(dir * s * 0.165, s * 0.275);
      // Mirror the tilt so both brows angle toward the beak together.
      canvas.rotate(dir * pose.browAngle);
      canvas.drawLine(
        Offset(-s * 0.085, 0),
        Offset(s * 0.085, 0),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawBeak(Canvas canvas, double s, _Pose pose) {
    final beak = Paint()..color = AppColors.sun;
    final beakDark = Paint()..color = AppColors.sunDark;
    const topY = 0.545;

    final w = s * 0.085;
    final h = s * 0.085;

    final upper = Path()
      ..moveTo(-w, s * topY)
      ..lineTo(w, s * topY)
      ..lineTo(0, s * (topY + 0.075))
      ..close();
    canvas.drawPath(upper, beak);

    if (pose.beakOpen > 0.02) {
      // Lower mandible drops open, hinged at the beak's corners.
      final drop = pose.beakOpen * h * 0.85;
      final lower = Path()
        ..moveTo(-w * 0.82, s * topY + 1)
        ..lineTo(w * 0.82, s * topY + 1)
        ..lineTo(0, s * topY + drop + h * 0.30)
        ..close();
      canvas.drawPath(lower, beakDark);
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.from != from ||
      old.to != to ||
      old.morph != morph ||
      old.bob != bob ||
      old.blink != blink ||
      old.body != body;
}
