import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/views/onboarding/screens/goal_confirmation_screen.dart';

// ─── Data Models ───────────────────────────────────────────────────────────────

class SkillCard {
  final String title;
  final int score;
  final List<String> tags;
  const SkillCard({required this.title, required this.score, required this.tags});
}

class FeedbackConfig {
  final String scenarioTitle;
  final int overallScore;
  final List<SkillCard> skills;
  final List<String> insights;
  final List<String> improvements;

  const FeedbackConfig({
    required this.scenarioTitle,
    required this.overallScore,
    required this.skills,
    required this.insights,
    required this.improvements,
  });

  static FeedbackConfig demo = const FeedbackConfig(
    scenarioTitle: 'Salary Negotiation',
    overallScore: 82,
    skills: [
      SkillCard(
        title: 'Tone & Delivery',
        score: 88,
        tags: ['Confident', 'Natural'],
      ),
      SkillCard(
        title: 'Speech Clarity',
        score: 79,
        tags: ['Clear', 'Paced'],
      ),
      SkillCard(
        title: 'Content Strategy',
        score: 74,
        tags: ['Structured', 'Focused'],
      ),
    ],
    insights: [
      'You maintained a calm and assertive tone throughout the negotiation, which is a strong signal of confidence to the other party.',
      'Your arguments were well-structured and backed by relevant context. Try to tie your asks more directly to business outcomes.',
      'Pausing strategically before responding showed great composure. Continue leveraging silence as a negotiation tool.',
    ],
    improvements: [
      'Speak slower during key points to let them land',
      'Maintain consistent volume — avoid trailing off at sentence ends',
      'Ask more clarifying questions to understand the other side',
    ],
  );
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class RoleplayFeedbackScreen extends StatefulWidget {
  final FeedbackConfig config;
  final bool isOnboarding;

  const RoleplayFeedbackScreen({
    super.key,
    required this.config,
    this.isOnboarding = false,
  });

  @override
  State<RoleplayFeedbackScreen> createState() => _RoleplayFeedbackScreenState();
}

class _RoleplayFeedbackScreenState extends State<RoleplayFeedbackScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();

    // Score ring animation
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: widget.config.overallScore / 100)
        .animate(CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic));

    // Progress bar animations (staggered)
    _barControllers = List.generate(
      widget.config.skills.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      ),
    );
    _barAnimations = List.generate(
      widget.config.skills.length,
      (i) => Tween<double>(
        begin: 0,
        end: widget.config.skills[i].score / 100,
      ).animate(CurvedAnimation(parent: _barControllers[i], curve: Curves.easeOutCubic)),
    );

    // Staggered start
    _scoreController.forward();
    for (int i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 150), () {
        if (mounted) _barControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    for (final c in _barControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.s8),
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.s32),
                    _buildScoreSection(context),
                    const SizedBox(height: AppSpacing.s32),
                    _buildSectionLabel('SKILL BREAKDOWN'),
                    const SizedBox(height: AppSpacing.s12),
                    ...List.generate(
                      widget.config.skills.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _buildSkillCard(widget.config.skills[i], _barAnimations[i]),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _buildSectionLabel('AI COACH INSIGHTS'),
                    const SizedBox(height: AppSpacing.s12),
                    _buildInsightsCard(),
                    const SizedBox(height: AppSpacing.s24),
                    _buildSectionLabel('IMPROVE NEXT TIME'),
                    const SizedBox(height: AppSpacing.s12),
                    _buildImprovementsCard(),
                    const SizedBox(height: AppSpacing.s32),
                    _buildBottomActions(context),
                    const SizedBox(height: AppSpacing.s16),
                    _buildFooter(context),
                    const SizedBox(height: AppSpacing.s24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8, vertical: AppSpacing.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'CommuniQ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, color: AppColors.textSecondary),
            onPressed: () => HapticFeedback.lightImpact(),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION PERFORMANCE',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.config.scenarioTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  // ─── Score Section ───────────────────────────────────────────────────────────

  Widget _buildScoreSection(BuildContext context) {
    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (_, __) {
              final value = _scoreAnimation.value;
              final displayScore = (value * widget.config.overallScore /
                      (widget.config.overallScore / 100))
                  .round();

              return SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: _ScoreRingPainter(progress: value),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$displayScore',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        const Text(
                          '%',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.s20),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.bar_chart_rounded,
                size: 16, color: AppColors.primaryLight),
            label: const Text(
              'View Analysis',
              style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Label ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }

  // ─── Skill Card ──────────────────────────────────────────────────────────────

  Widget _buildSkillCard(SkillCard skill, Animation<double> barAnim) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                skill.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                '${skill.score}%',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          // Animated progress bar
          AnimatedBuilder(
            animation: barAnim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barAnim.value,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: skill.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Insights Card ───────────────────────────────────────────────────────────

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.config.insights.map((insight) {
          final isLast = widget.config.insights.last == insight;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Improvements Card ───────────────────────────────────────────────────────

  Widget _buildImprovementsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: widget.config.improvements.map((tip) {
          final isLast = widget.config.improvements.last == tip;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primaryLight,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Bottom Actions ──────────────────────────────────────────────────────────

  Widget _buildBottomActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (widget.isOnboarding) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const GoalConfirmationScreen()),
                  (_) => false,
                );
              } else {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              widget.isOnboarding ? 'Continue' : 'Practice Again',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        // Secondary
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Try New Scenario',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: const Text(
          'Back to Home',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Custom Painter: Score Ring ───────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;

  _ScoreRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    // Track (background) arc
    final trackPaint = Paint()
      ..color = const Color(0xFF1E2533)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Primary filled arc
    final primaryPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Secondary lighter arc (small accent)
    final lightPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Draw primary arc up to 80% of fill
    final primaryEnd = sweepAngle * 0.85;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      primaryEnd,
      false,
      primaryPaint,
    );

    // Draw lighter accent for last 15%
    if (progress > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + primaryEnd,
        sweepAngle - primaryEnd,
        false,
        lightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
