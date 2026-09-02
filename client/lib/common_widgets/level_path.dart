import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/shadows.dart';

enum LevelNodeState {
  /// Finished. Shows a check and the coins earned.
  done,

  /// The next level to play — the one node that draws attention.
  current,

  /// Not yet reachable.
  locked,
}

/// One stop on the learning path.
///
/// The current node pulses gently and carries a "START" flag so the eye lands
/// on it immediately; done nodes are solid; locked nodes are muted and flat.
class LevelNode extends StatefulWidget {
  const LevelNode({
    super.key,
    required this.index,
    required this.state,
    required this.onTap,
    this.color,
    this.coins,
    this.size = 76,
  });

  /// Zero-based position, used only for the label.
  final int index;

  final LevelNodeState state;
  final VoidCallback onTap;
  final Color? color;

  /// Coins earned, shown on completed nodes.
  final int? coins;

  final double size;

  @override
  State<LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _held = false;

  @override
  void initState() {
    super.initState();
    if (widget.state == LevelNodeState.current) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (widget.state == LevelNodeState.current) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _fill => switch (widget.state) {
        LevelNodeState.done => AppColors.success,
        LevelNodeState.current => widget.color ?? AppColors.brand,
        LevelNodeState.locked => AppColors.bgSunk,
      };

  IconData get _icon => switch (widget.state) {
        LevelNodeState.done => Icons.check_rounded,
        LevelNodeState.current => Icons.play_arrow_rounded,
        LevelNodeState.locked => Icons.lock_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final locked = widget.state == LevelNodeState.locked;
    final depth = _held ? AppShadow.pressedDepth : 6.0;
    final travel = 6.0 - depth;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.state == LevelNodeState.current)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StartFlag(color: _fill),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _held = true),
          onTapUp: (_) => setState(() => _held = false),
          onTapCancel: () => setState(() => _held = false),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final scale = widget.state == LevelNodeState.current
                  ? 1 + 0.035 * Curves.easeInOut.transform(_pulse.value)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: AnimatedContainer(
              duration: AppMotion.press,
              curve: AppMotion.ease,
              transform: Matrix4.translationValues(0, travel, 0),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: locked ? AppColors.outline : AppColors.shadowFor(_fill),
                  width: 2,
                ),
                boxShadow: locked
                    ? null
                    : AppShadow.hardWith(AppColors.shadowFor(_fill), y: depth),
              ),
              child: Icon(
                _icon,
                size: widget.size * 0.42,
                color: locked ? AppColors.inkSoft : AppColors.inkOnDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.index + 1}',
          style: AppTextStyles.labelSmall.copyWith(
            color: locked ? AppColors.inkSoft : AppColors.inkMuted,
          ),
        ),
        if (widget.state == LevelNodeState.done && (widget.coins ?? 0) > 0)
          Text(
            '🪙 ${widget.coins}',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.sunDark),
          ),
      ],
    );
  }
}

class _StartFlag extends StatelessWidget {
  const _StartFlag({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 2),
        boxShadow: AppShadow.hardWith(AppColors.shadowFor(color), y: 3),
      ),
      child: Text(
        'START',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

/// Draws one row's share of the winding trail between level nodes.
///
/// A row paints from its own node down to the row boundary, and from the
/// boundary up to its node — meeting the neighbouring row at the same point.
/// Splitting it this way means no row ever paints outside its own bounds,
/// which a single full-height painter inside a ListView could not guarantee.
class LevelTrailPainter extends CustomPainter {
  LevelTrailPainter({
    required this.selfAlign,
    required this.incomingFromAlign,
    required this.outgoingToAlign,
    required this.incomingTravelled,
    required this.outgoingTravelled,
  });

  /// Horizontal alignment (-1..1) of this row's node.
  final double selfAlign;

  /// Alignment of the previous node, or null for the first row.
  final double? incomingFromAlign;

  /// Alignment of the next node, or null for the last row.
  final double? outgoingToAlign;

  /// Travelled segments are drawn in the success colour, the rest muted.
  final bool incomingTravelled;
  final bool outgoingTravelled;

  double _x(double align, double width) => (align + 1) / 2 * width;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = _x(selfAlign, size.width);
    final cy = size.height / 2;

    if (incomingFromAlign != null) {
      // Meet the previous row halfway across, at the top edge.
      final midX = _x((incomingFromAlign! + selfAlign) / 2, size.width);
      _dashed(canvas, Offset(midX, 0), Offset(cx, cy), incomingTravelled);
    }

    if (outgoingToAlign != null) {
      final midX = _x((selfAlign + outgoingToAlign!) / 2, size.width);
      _dashed(canvas, Offset(cx, cy), Offset(midX, size.height),
          outgoingTravelled);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, bool travelled) {
    final paint = Paint()
      ..color = travelled ? AppColors.success : AppColors.outline
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx, a.dy + (b.dy - a.dy) * 0.55,
        b.dx, b.dy - (b.dy - a.dy) * 0.55,
        b.dx, b.dy,
      );

    const dash = 11.0;
    const gap = 9.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(LevelTrailPainter old) =>
      old.selfAlign != selfAlign ||
      old.incomingFromAlign != incomingFromAlign ||
      old.outgoingToAlign != outgoingToAlign ||
      old.incomingTravelled != incomingTravelled ||
      old.outgoingTravelled != outgoingTravelled;
}
