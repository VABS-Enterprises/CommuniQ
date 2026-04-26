import 'dart:math';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/roleplay_intro_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class PlanReadyScreen extends StatefulWidget {
  const PlanReadyScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

enum _Phase { building, revealed }

class _PlanReadyScreenState extends State<PlanReadyScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.building;

  // Building phase — sequential item appearance
  late AnimationController _buildItemsCtrl;

  // Reveal phase — staggered entrance
  late AnimationController _revealCtrl;

  static const _buildDuration = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();

    _buildItemsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Switch to reveal phase after building completes
    Future.delayed(_buildDuration, () {
      if (!mounted) return;
      setState(() => _phase = _Phase.revealed);
      _revealCtrl.forward();
    });
  }

  @override
  void dispose() {
    _buildItemsCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  void _goToRoleplayIntro() {
    Navigator.push(
      context,
      slideRoute(RoleplayIntroScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: _phase == _Phase.building
                ? _BuildingView(
                    key: const ValueKey('building'),
                    itemsCtrl: _buildItemsCtrl,
                    data: widget.data,
                  )
                : _RevealView(
                    key: const ValueKey('revealed'),
                    revealCtrl: _revealCtrl,
                    data: widget.data,
                    onContinue: _goToRoleplayIntro,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 1 — Building
// ─────────────────────────────────────────────────────────────────────────────

class _BuildingView extends StatefulWidget {
  final AnimationController itemsCtrl;
  final OnboardingData data;

  const _BuildingView({
    super.key,
    required this.itemsCtrl,
    required this.data,
  });

  @override
  State<_BuildingView> createState() => _BuildingViewState();
}

class _BuildingViewState extends State<_BuildingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateCtrl;

  static const _steps = [
    'Analyzing your communication style',
    'Mapping your challenges',
    'Calibrating difficulty level',
    'Preparing your first session',
  ];

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Rotating arc loader
          AnimatedBuilder(
            animation: Listenable.merge([_rotateCtrl, widget.itemsCtrl]),
            builder: (_, __) => _buildLoader(),
          ),

          const SizedBox(height: 28),

          const Text(
            'Building your plan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Personalizing everything to you',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
            ),
          ),

          const SizedBox(height: 22),

          // Progress bar
          AnimatedBuilder(
            animation: widget.itemsCtrl,
            builder: (_, __) => _buildProgressBar(),
          ),

          const SizedBox(height: 28),

          // Sequential build steps
          AnimatedBuilder(
            animation: widget.itemsCtrl,
            builder: (_, __) => Column(
              children: List.generate(_steps.length, (i) => _buildStep(i)),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
          ),
          // Rotating gradient arc
          Transform.rotate(
            angle: _rotateCtrl.value * 2 * pi,
            child: CustomPaint(
              size: const Size(148, 148),
              painter: _ArcPainter(
                progress: widget.itemsCtrl.value,
                primaryColor: AppColors.primary,
                lightColor: AppColors.primaryLight,
              ),
            ),
          ),
          // Inner soft glow
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          // Core icon circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final p = widget.itemsCtrl.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _currentLabel(p),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              '${(p * 100).round()}%',
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Track
              Container(
                height: 4,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: 4,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currentLabel(double p) {
    if (p < 0.22) return 'Analyzing style...';
    if (p < 0.44) return 'Mapping challenges...';
    if (p < 0.66) return 'Calibrating level...';
    if (p < 0.88) return 'Building sessions...';
    return 'Almost ready...';
  }

  Widget _buildStep(int i) {
    final p = widget.itemsCtrl.value;
    final stepStart = i * 0.22;
    final isComplete = p >= stepStart + 0.22;
    final isCurrent = p >= stepStart && !isComplete;
    final isPending = p < stepStart;

    return AnimatedOpacity(
      opacity: isPending ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 280),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isComplete
                    ? Container(
                        key: const ValueKey('check'),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF22C55E),
                          size: 13,
                        ),
                      )
                    : isCurrent
                        ? Container(
                            key: const ValueKey('spinner'),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryLight,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _steps[i],
                style: TextStyle(
                  color: isComplete
                      ? AppColors.textSecondary
                      : isCurrent
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                  fontSize: 13.5,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rotating arc painter
// ─────────────────────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color lightColor;

  const _ArcPainter({
    required this.progress,
    required this.primaryColor,
    required this.lightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arc sweep grows from π/2 → 5π/3 as progress goes 0 → 1
    final sweepAngle = pi / 2 + progress * (7 * pi / 6);

    // Solid arc
    final arcPaint = Paint()
      ..color = lightColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);

    // Bright leading dot
    final endAngle = -pi / 2 + sweepAngle;
    final dotX = center.dx + radius * cos(endAngle);
    final dotY = center.dy + radius * sin(endAngle);

    canvas.drawCircle(
      Offset(dotX, dotY),
      4.5,
      Paint()
        ..color = lightColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.lightColor != lightColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 2 — Personalized Reveal
// Previews real levels from communiq_levels_v4.json so the user sees
// the actual content waiting for them, calibrated to their level + goal.
// ─────────────────────────────────────────────────────────────────────────────

class _RevealView extends StatelessWidget {
  final AnimationController revealCtrl;
  final OnboardingData data;
  final VoidCallback onContinue;

  const _RevealView({
    super.key,
    required this.revealCtrl,
    required this.data,
    required this.onContinue,
  });

  Animation<double> _anim(double start, double end) => CurvedAnimation(
        parent: revealCtrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );

  @override
  Widget build(BuildContext context) {
    final level = data.level ?? 'Beginner';
    final goal = data.primaryGoal ?? 'Confidence';
    final preview = _modulePreview(level, goal);
    final levelColor = _levelColor(level);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: revealCtrl,
        builder: (_, __) => SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── 0. Progress bar + back button ──────────────────────────────
            buildOnboardingHeader(context, 6),

            const SizedBox(height: 16),

            // ── 1. Header ──────────────────────────────────────────────────
            FadeTransition(
              opacity: _anim(0.0, 0.45),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.2), end: Offset.zero)
                    .animate(_anim(0.0, 0.45)),
                child: _buildHeader(level, goal, levelColor),
              ),
            ),

            const SizedBox(height: 14),

            // ── 2. Coach insight — personalized from style + challenges ────
            FadeTransition(
              opacity: _anim(0.18, 0.58),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_anim(0.18, 0.58)),
                child: _buildCoachInsight(
                  style: data.speakingStyle,
                  challenges: data.challenges,
                  goal: goal,
                  note: data.speakingNote,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 3. Module preview card ─────────────────────────────────────
            FadeTransition(
              opacity: _anim(0.32, 0.70),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_anim(0.32, 0.70)),
                child: _buildModuleCard(preview),
              ),
            ),

            const SizedBox(height: 10),

            // ── 4. Roleplay teaser ─────────────────────────────────────────
            FadeTransition(
              opacity: _anim(0.44, 0.78),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.15), end: Offset.zero)
                    .animate(_anim(0.44, 0.78)),
                child: _buildRoleplayTeaser(),
              ),
            ),

            const SizedBox(height: 16),

            // ── 4. CTA ─────────────────────────────────────────────────────
            FadeTransition(
              opacity: _anim(0.55, 1.0),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.3), end: Offset.zero)
                    .animate(_anim(0.55, 1.0)),
                child: Column(
                  children: [
                    OnboardingButton(
                      label: 'Unlock All 150 Sessions',
                      showGradient: false,
                      onPressed: onContinue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Free forever · No credit card needed',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String level, String goal, Color levelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 13),
              SizedBox(width: 6),
              Text(
                'Learning path ready',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '150 sessions,\nall built for you.',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Calibrated for '),
              TextSpan(
                text: level,
                style: TextStyle(
                    color: levelColor, fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: goal,
                style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Module card — real level content from communiq_levels_v4.json ──────────

  Widget _buildModuleCard(_ModulePreview preview) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Journey header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.journeyTitle.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview.levelRange,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.flag_rounded,
                          color: AppColors.primaryLight, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'YOUR START',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: AppColors.cardBorder),

          // Level rows
          ...preview.levels.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            return Column(
              children: [
                _levelRow(e.value.id, e.value.title, isFirst),
                if (e.key < preview.levels.length - 1)
                  Container(
                    height: 1,
                    color: AppColors.cardBorder.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              ],
            );
          }),

          // Footer — remaining count + quick stats
          Container(height: 1, color: AppColors.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.more_horiz_rounded,
                    color: AppColors.textMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  '+${preview.remainingCount} more sessions',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _footerChip(Icons.map_rounded, '15 journeys'),
                const SizedBox(width: 6),
                _footerChip(Icons.timer_rounded, '~10 min each'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelRow(int id, String title, bool isActive) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $id',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'READY',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Locked row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded,
                color: AppColors.textMuted, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $id',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Coach insight — personalized from speaking style + challenges ─────────

  Widget _buildCoachInsight({
    required String? style,
    required List<String> challenges,
    required String goal,
    required String? note,
  }) {
    final insight = _generateInsight(style, challenges, goal);
    final hasNote = note != null && note.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppColors.primaryLight, size: 13),
              ),
              const SizedBox(width: 8),
              const Text(
                'YOUR COACH\'S READ',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Insight text
          Text(
            insight,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),

          // Show their own words back if they wrote a note
          if (hasNote) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.primary.withValues(alpha: 0.15)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You said  ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    '"${note!.trim()}"',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Generates a 2-sentence personalized insight from speaking style
  /// and selected challenges. Each combination feels like a real coach
  /// who actually read what the user said.
  String _generateInsight(
      String? style, List<String> challenges, String goal) {
    final hasNervous = challenges.contains('Feeling nervous');
    final hasNoWords = challenges.contains('Running out of words');
    final hasLostIdeas = challenges.contains('Ideas get lost in translation');
    final hasInterrupted = challenges.contains('Being interrupted or talked over');
    final hasAvoidance = challenges.contains('Avoiding difficult talks');
    final hasNoConfidence = challenges.contains('Lack of confidence');
    final hasPace = challenges.contains('Speaking too fast or slow');

    switch (style) {
      case 'Hesitant & Unsure':
        if (hasNervous || hasNoConfidence) {
          return 'You know what to say — you just don\'t trust yourself to say it yet. '
              'Your sessions build that trust fast, starting with scenarios you can win before pushing you further.';
        }
        if (hasNoWords) {
          return 'The words are there — they just disappear at the wrong moment. '
              'Your sessions train your mind to stay clear under pressure so you never go blank again.';
        }
        return 'You have the insight — you\'re just missing the certainty. '
            'Your sessions train you to back yourself in conversations, one at a time.';

      case 'Calm & Quiet':
        if (hasInterrupted) {
          return 'Your thoughtful, quiet approach is a strength — not a weakness. '
              'Your sessions teach you to hold your ground without raising your voice, so people stop talking over you.';
        }
        if (hasAvoidance) {
          return 'You keep the peace because you care — but silence has a cost. '
              'Your sessions gradually build your comfort with tension until it stops feeling like a threat.';
        }
        return 'You choose words carefully — that\'s genuinely rare. '
            'Your sessions channel that precision into confident, assertive communication that commands attention without force.';

      case 'Fast & Energetic':
        if (hasLostIdeas || hasPace) {
          return 'Your energy is your superpower — but it sometimes outruns your message. '
              'Your sessions train you to pause at exactly the right moments so your best ideas land the way you intend.';
        }
        if (hasInterrupted) {
          return 'You have presence — people just need to feel it more. '
              'Your sessions focus on grounding your energy so others follow your lead instead of talking over it.';
        }
        return 'You\'re naturally expressive and that\'s powerful. '
            'Your sessions focus on directing that energy with precision so every word lands with intention.';

      case 'Confident & Direct':
        if (hasAvoidance || hasInterrupted) {
          return 'You already have the foundation — now it\'s about the edge cases. '
              'Your sessions go into high-pressure moments and difficult personalities where even confident speakers lose ground.';
        }
        if (hasLostIdeas) {
          return 'You speak with authority — but clarity is what makes people act on it. '
              'Your sessions sharpen how your ideas land so directness and understanding always come together.';
        }
        return 'You already know how to speak — now it\'s about mastery. '
            'Your sessions cover the moments that separate good communicators from truly unforgettable ones.';

      case 'Friendly & Casual':
        if (hasAvoidance) {
          return 'Your warmth puts people at ease — that\'s genuinely rare. '
              'Your sessions channel it into the conversations that feel hardest, because warmth is exactly what those moments need.';
        }
        if (hasInterrupted || hasNoConfidence) {
          return 'You make people comfortable — now let\'s make sure they take you seriously too. '
              'Your sessions add confident structure to your natural ease without changing what makes you you.';
        }
        return 'You put people at ease effortlessly — that\'s a real skill. '
            'Your sessions add intention and structure so you\'re just as comfortable in high-stakes conversations.';

      default:
        switch (goal) {
          case 'Confidence':
            return 'Your confidence is closer than you think. '
                'Your sessions start exactly where you are and push you further than you expect — one real conversation at a time.';
          case 'Tough Conversations':
            return 'Tough conversations get easier with the right preparation. '
                'Your sessions put you in the exact scenarios you\'ve been avoiding — so they stop feeling impossible.';
          case 'Clarity':
            return 'Saying exactly what you mean is a trainable skill. '
                'Your sessions sharpen how you structure and deliver ideas until clarity is your default, not something you have to work for.';
          case 'Public Speaking':
            return 'Every great speaker was once exactly where you are. '
                'Your sessions put you on the virtual stage repeatedly until the nerves become fuel, not a barrier.';
          case 'Persuasion':
            return 'Persuasion isn\'t about pressure — it\'s about understanding people. '
                'Your sessions train you to read the room and make your case at exactly the right moment.';
          default:
            return 'Your sessions are built around everything you told us. '
                'Every scenario you\'ll face has been chosen because it maps directly to what matters most to you.';
        }
    }
  }

  Widget _footerChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 11),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Roleplay teaser — companion to the module card ────────────────────────

  int _roleplayCount() {
    switch ((data.level ?? '').toLowerCase()) {
      case 'advanced':
        return 18;
      case 'intermediate':
        return 12;
      default:
        return 8;
    }
  }

  String _contextsLabel() {
    final c = data.contexts;
    if (c.isEmpty) return data.primaryGoal ?? 'your goal';
    if (c.length == 1) return c.first;
    return '${c.first} & ${c[1]}';
  }

  Widget _buildRoleplayTeaser() {
    final count = _roleplayCount();
    final label = _contextsLabel();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          // Mic icon in gradient circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 14),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13.5, height: 1.3),
                    children: [
                      TextSpan(
                        text: '$count roleplays ',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: 'also built for you',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Focused on $label',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Unlock badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.emerald.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_open_rounded,
                    color: AppColors.emerald, size: 10),
                SizedBox(width: 4),
                Text(
                  'Unlocked',
                  style: TextStyle(
                    color: AppColors.emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Module data — sourced from communiq_levels_v4.json ────────────────────

  _ModulePreview _modulePreview(String level, String goal) {
    if (level == 'Advanced') {
      if (goal == 'Tough Conversations') {
        return const _ModulePreview(
          journeyTitle: 'Difficult Conversations',
          levelRange: 'Levels 91–100',
          levels: [
            _LP(91, 'Telling a Friend Something Hard'),
            _LP(92, 'Confronting Someone Who Takes Credit'),
            _LP(93, 'Rebuilding Trust After It Has Been Broken'),
            _LP(94, 'Bringing Up a Sensitive Personal Topic'),
          ],
          remainingCount: 56,
        );
      }
      if (goal == 'Public Speaking') {
        return const _ModulePreview(
          journeyTitle: 'Public Speaking Mastery',
          levelRange: 'Levels 101–110',
          levels: [
            _LP(101, 'Opening a Presentation with Impact'),
            _LP(102, 'Telling a Story to an Audience'),
            _LP(103, 'Handling Tough Q&A Questions'),
            _LP(104, 'Contributing on a Panel'),
          ],
          remainingCount: 46,
        );
      }
      if (goal == 'Persuasion') {
        return const _ModulePreview(
          journeyTitle: 'Influence & Persuasion',
          levelRange: 'Levels 71–80',
          levels: [
            _LP(71, 'Getting Buy-In on a New Idea'),
            _LP(72, 'Overcoming Objections'),
            _LP(73, 'Pitching Under Time Pressure'),
            _LP(74, 'Convincing a Sceptical Stakeholder'),
          ],
          remainingCount: 76,
        );
      }
      // Confidence, Clarity, default
      return const _ModulePreview(
        journeyTitle: 'Professional Presence',
        levelRange: 'Levels 61–70',
        levels: [
          _LP(61, 'Making a Strong First Impression'),
          _LP(62, 'Speaking Up in a Large Meeting'),
          _LP(63, 'Networking at a Professional Event'),
          _LP(64, 'Asking for a Promotion'),
        ],
        remainingCount: 86,
      );
    }

    if (level == 'Intermediate') {
      if (goal == 'Tough Conversations') {
        return const _ModulePreview(
          journeyTitle: 'Navigating Disagreements',
          levelRange: 'Levels 51–60',
          levels: [
            _LP(51, "Disagreeing with a Friend's Decision"),
            _LP(52, 'Receiving Critical Feedback'),
            _LP(53, 'Clearing Up a Misunderstanding'),
            _LP(54, 'Standing Firm Under Group Pressure'),
          ],
          remainingCount: 96,
        );
      }
      if (goal == 'Persuasion') {
        return const _ModulePreview(
          journeyTitle: 'Influence & Persuasion',
          levelRange: 'Levels 71–80',
          levels: [
            _LP(71, 'Getting Buy-In on a New Idea'),
            _LP(72, 'Overcoming Objections'),
            _LP(73, 'Pitching Under Time Pressure'),
            _LP(74, 'Convincing a Sceptical Stakeholder'),
          ],
          remainingCount: 76,
        );
      }
      if (goal == 'Public Speaking') {
        return const _ModulePreview(
          journeyTitle: 'Professional Presence',
          levelRange: 'Levels 61–70',
          levels: [
            _LP(61, 'Making a Strong First Impression'),
            _LP(62, 'Speaking Up in a Large Meeting'),
            _LP(63, 'Networking at a Professional Event'),
            _LP(64, 'Asking for a Promotion'),
          ],
          remainingCount: 86,
        );
      }
      if (goal == 'Confidence') {
        return const _ModulePreview(
          journeyTitle: 'Expressing Yourself',
          levelRange: 'Levels 21–30',
          levels: [
            _LP(21, 'Sharing a Differing Opinion'),
            _LP(22, 'Talking About Your Emotions'),
            _LP(23, 'Telling a Personal Story'),
            _LP(24, "Admitting You Don't Know"),
          ],
          remainingCount: 126,
        );
      }
      // Clarity, default
      return const _ModulePreview(
        journeyTitle: 'Workplace Basics',
        levelRange: 'Levels 31–40',
        levels: [
          _LP(31, 'Introducing Yourself to a New Team'),
          _LP(32, 'Asking Your Manager for Clarification'),
          _LP(33, 'Contributing in a Team Meeting'),
          _LP(34, 'Sending a Professional Email'),
        ],
        remainingCount: 116,
      );
    }

    // Beginner (default)
    return const _ModulePreview(
      journeyTitle: 'Social Foundations',
      levelRange: 'Levels 1–10',
      levels: [
        _LP(1, 'Introducing Yourself'),
        _LP(2, 'Starting a Conversation'),
        _LP(3, 'Making Small Talk'),
        _LP(4, 'Paying a Genuine Compliment'),
      ],
      remainingCount: 146,
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'Intermediate':
        return AppColors.amber;
      case 'Advanced':
        return AppColors.violetLight;
      default:
        return AppColors.emerald;
    }
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _LP {
  const _LP(this.id, this.title);
  final int id;
  final String title;
}

class _ModulePreview {
  const _ModulePreview({
    required this.journeyTitle,
    required this.levelRange,
    required this.levels,
    required this.remainingCount,
  });
  final String journeyTitle;
  final String levelRange;
  final List<_LP> levels;
  final int remainingCount;
}
