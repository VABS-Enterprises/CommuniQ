import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/goal_confirmation_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

/// Social proof + transformation screen shown after Level Selection.
/// Slot: between LevelSelectionScreen and GoalConfirmationScreen.
class TransformationScreen extends StatefulWidget {
  const TransformationScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<TransformationScreen> createState() => _TransformationScreenState();
}

class _TransformationScreenState extends State<TransformationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _anim(double start, double end) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );

  // Dynamic content based on level
  List<_Pair> _getPairs() {
    switch (widget.data.level) {
      case 'Intermediate':
        return const [
          _Pair(
            before: 'Stumble when put on the spot',
            after: 'Think on your feet — calm and clear',
          ),
          _Pair(
            before: 'Sound unsure even when you\'re not',
            after: 'Come across confident and direct',
          ),
          _Pair(
            before: 'Conversations trail off awkwardly',
            after: 'Know how to land your point and move on',
          ),
        ];
      case 'Advanced':
        return const [
          _Pair(
            before: 'Competent — but forgettable',
            after: 'The person everyone remembers',
          ),
          _Pair(
            before: 'Good ideas that don\'t land well',
            after: 'Persuade people without pushing',
          ),
          _Pair(
            before: 'Tense in high-stakes conversations',
            after: 'Calm, sharp, and fully in control',
          ),
        ];
      default: // Beginner
        return const [
          _Pair(
            before: 'Freeze on "tell me about yourself"',
            after: 'Answer confidently in 60 seconds',
          ),
          _Pair(
            before: 'Run out of words mid-conversation',
            after: 'Keep the conversation going naturally',
          ),
          _Pair(
            before: 'Constant "uh", "um", awkward pauses',
            after: 'Speak with calm, steady confidence',
          ),
        ];
    }
  }

  List<String> _getMilestones(String level) {
    switch (level) {
      case 'Intermediate':
        return ['Clarity', 'Natural Flow', 'Full Command'];
      case 'Advanced':
        return ['Presence', 'Authority', 'Mastery'];
      default:
        return ['Foundation', 'Confidence', 'Control'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = _getPairs();
    final level = widget.data.level ?? 'Beginner';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 4),

                const SizedBox(height: 32),

                // ── Headline ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.0, 0.40),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.0, 0.40)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _levelColor(level).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  _levelColor(level).withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            '$level · Your starting point',
                            style: TextStyle(
                              color: _levelColor(level),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          "Here's what you'll\nunlock",
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Real outcomes from people who started where you are',
                          style: TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Before/After table ─────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.2, 0.65),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.2, 0.65)),
                    child: _buildTransformTable(pairs),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 3-week journey progress bar ────────────────────────────
                FadeTransition(
                  opacity: _anim(0.50, 0.90),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.50, 0.90)),
                    child: _buildProgressGraph(level),
                  ),
                ),

                const Spacer(),

                // ── CTA ────────────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.70, 1.0),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(_anim(0.70, 1.0)),
                    child: OnboardingButton(
                      label: 'I want this for myself',
                      onPressed: () => Navigator.push(
                        context,
                        slideRoute(GoalConfirmationScreen(data: widget.data)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Before/After Table ─────────────────────────────────────────────────────

  Widget _buildTransformTable(List<_Pair> pairs) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Before',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'After training',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pairs
          ...pairs.asMap().entries.map((e) {
            final isLast = e.key == pairs.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Before
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.remove_rounded,
                                color: AppColors.error,
                                size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value.before,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // After
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_forward_rounded,
                                color: AppColors.success,
                                size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value.after,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                      height: 1,
                      color: AppColors.outline,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 18)),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Progress Graph ────────────────────────────────────────────────────────

  Widget _buildProgressGraph(String level) {
    final milestones = _getMilestones(level);
    final animation = _anim(0.42, 0.96);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Skill Progression',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Icon(Icons.show_chart_rounded,
                  color: AppColors.brandLight, size: 16),
            ],
          ),
          const SizedBox(height: 14),

          // Graph canvas
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return SizedBox(
                height: 88,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ProgressGraphPainter(
                    progress: animation.value,
                    bgColor: AppColors.surface,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // X-axis milestone labels
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final p = animation.value;
              const xThresholds = [0.0, 0.33, 0.67, 1.0];
              final labels = ['Now', ...milestones];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (i) {
                  final reached = p >= xThresholds[i] - 0.04;
                  final align = i == 0
                      ? CrossAxisAlignment.start
                      : i == 3
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center;
                  return Column(
                    crossAxisAlignment: align,
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: reached
                              ? AppColors.inkMuted
                              : AppColors.inkSoft,
                          fontSize: 10.5,
                          fontWeight:
                              reached ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _levelColor(String level) {
    switch (level) {
      case 'Intermediate':
        return AppColors.sun;
      case 'Advanced':
        return AppColors.brandLight;
      default:
        return AppColors.success;
    }
  }

  Widget _backButton() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.inkMuted,
        size: 16,
      ),
    );
  }
}

class _Pair {
  final String before;
  final String after;
  const _Pair({required this.before, required this.after});
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Graph Painter
// Draws an animated bezier line chart rising from low (left) to high (right),
// with gradient fill underneath and glowing dots at each milestone.
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressGraphPainter extends CustomPainter {
  const _ProgressGraphPainter({
    required this.progress,
    required this.bgColor,
  });

  final double progress; // 0.0 → 1.0
  final Color bgColor;

  // Normalised data points — x: time (0=now, 1=week3), y: skill (0=top, 1=bottom)
  static const _pts = [
    Offset(0.00, 0.90), // Now  — low skill
    Offset(0.33, 0.65), // Week 1
    Offset(0.67, 0.32), // Week 2
    Offset(1.00, 0.07), // Week 3 — high skill
  ];

  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF7C3AED);
  static const _indigoLight = Color(0xFF818CF8);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;

    // Convert normalised points to canvas coords
    final pts = _pts.map((p) => Offset(p.dx * w, p.dy * h)).toList();

    // Build smooth cubic-bezier path through all points
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cpx = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(
        cpx, pts[i].dy,
        cpx, pts[i + 1].dy,
        pts[i + 1].dx, pts[i + 1].dy,
      );
    }

    // Compute the animated portion of the path
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final drawLen = metric.length * progress.clamp(0.0, 1.0);
    final drawn = metric.extractPath(0, drawLen);

    // End-point of the animated line (for closing the fill shape)
    Offset endPt = pts[0];
    if (progress > 0) {
      final t = metric.getTangentForOffset(drawLen);
      if (t != null) endPt = t.position;
    }

    // ── 1. Subtle horizontal grid lines ──────────────────────────────────
    final gridPaint = Paint()
      // Was white at 5%, invisible against the light chart ground.
      ..color = AppColors.outline.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── 2. Gradient fill under the drawn curve ────────────────────────────
    if (progress > 0.01) {
      final fillPath = Path.from(drawn)
        ..lineTo(endPt.dx, h)
        ..lineTo(pts[0].dx, h)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()..color = _indigo.withValues(alpha: 0.15),
      );
    }

    // ── 3. Animated gradient line ─────────────────────────────────────────
    canvas.drawPath(
      drawn,
      Paint()
        ..color = _indigo
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── 4. Glowing milestone dots ─────────────────────────────────────────
    for (final pt in pts) {
      if (pt.dx > endPt.dx + 2) continue; // not yet reached

      // Outer glow
      canvas.drawCircle(
        pt, 9,
        Paint()
          ..color = _indigo.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Background fill (matches card)
      canvas.drawCircle(pt, 5, Paint()..color = bgColor);
      // Border ring
      canvas.drawCircle(
        pt, 5,
        Paint()
          ..color = _indigo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // Inner dot
      canvas.drawCircle(pt, 2.2, Paint()..color = _indigoLight);
    }
  }

  @override
  bool shouldRepaint(_ProgressGraphPainter old) =>
      old.progress != progress || old.bgColor != bgColor;
}
