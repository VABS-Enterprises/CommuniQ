import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/models/feedback_config.dart';
import 'package:communiq/models/session_result_model.dart';
import 'package:communiq/views/onboarding/screens/goal_confirmation_screen.dart';
import 'package:communiq/views/roleplay_view/screens/roleplay_setup_screen.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class RoleplayFeedbackScreen extends StatefulWidget {
  final FeedbackConfig config;

  /// Full session report — used by the "View Analysis" bottom sheet.
  /// Optional: if null, the button is still shown but with limited data.
  final SessionReport? report;

  final bool isOnboarding;

  /// XP earned in this session — shown as a banner below the score ring.
  /// Pass 0 (default) to hide the banner.
  final int xpAwarded;
  final int newLevel;
  final bool leveledUp;
  final List<String> newBadges;
  final int newStreak;

  const RoleplayFeedbackScreen({
    super.key,
    required this.config,
    this.report,
    this.isOnboarding = false,
    this.xpAwarded = 0,
    this.newLevel = 1,
    this.leveledUp = false,
    this.newBadges = const [],
    this.newStreak = 0,
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
                    if (widget.report?.recommendedNextType != null) ...[
                      const SizedBox(height: AppSpacing.s24),
                      _buildSectionLabel('RECOMMENDED NEXT'),
                      const SizedBox(height: AppSpacing.s12),
                      _buildRecommendedNextCard(context),
                    ],
                    const SizedBox(height: AppSpacing.s32),
                    _buildBottomActions(context),
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
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
          Expanded(
            child: Text(
              'CommuniQ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          const SizedBox(width: 48),
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

  Color _scoreColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  Color _scoreLightColor(int score) {
    if (score >= 75) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.red.shade200;
  }

  Widget _buildScoreSection(BuildContext context) {
    final scoreColor = _scoreColor(widget.config.overallScore);
    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (_, __) {
              final value = _scoreAnimation.value;
              final overallScore = widget.config.overallScore;
              final displayScore = overallScore == 0
                  ? 0
                  : (value * overallScore / (overallScore / 100)).round();

              return SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: value,
                    color: scoreColor,
                    lightColor: _scoreLightColor(overallScore),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$displayScore',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            color: scoreColor.withValues(alpha: 0.7),
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
            onPressed: () => _showAnalysisSheet(context),
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
          if (widget.xpAwarded > 0 ||
              widget.newBadges.isNotEmpty ||
              widget.newStreak > 0) ...[
            const SizedBox(height: AppSpacing.s16),
            _buildXpBanner(),
          ],
        ],
      ),
    );
  }

  void _showAnalysisSheet(BuildContext context) {
    final report = widget.report;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Detailed Analysis',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Individual scores ─────────────────────────────────
                  _buildSheetLabel('SKILL SCORES'),
                  const SizedBox(height: 12),
                  if (report != null) ...[
                    _buildScoreRow('Clarity', report.clarity),
                    _buildScoreRow('Fluency', report.fluency),
                    _buildScoreRow('Confidence', report.confidence),
                    _buildScoreRow('Vocabulary', report.vocabulary),
                    _buildScoreRow('Grammar', report.grammar),
                  ] else
                    ...widget.config.skills.map((s) => _buildScoreRow(s.title, s.score)),
                  const SizedBox(height: 24),

                  // ── Filler words ──────────────────────────────────────
                  _buildSheetLabel('FILLER WORDS'),
                  const SizedBox(height: 12),
                  if (report != null && report.fillerWordCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report.fillerWordCount} filler word${report.fillerWordCount == 1 ? '' : 's'} detected',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: report.fillerWords.map((word) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  '"$word"',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 10),
                          const Text(
                            'No filler words detected — clean speech!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Full transcript ───────────────────────────────────
                  _buildSheetLabel('FULL TRANSCRIPT'),
                  const SizedBox(height: 12),
                  if (report != null && report.rawTranscript.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        report.rawTranscript,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Transcript not available.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetLabel(String label) {
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

  Widget _buildScoreRow(String label, int score) {
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? AppColors.primary
            : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBanner() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // XP + level-up row
        if (widget.xpAwarded > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primaryLight, size: 20),
                const SizedBox(width: 8),
                Text(
                  '+${widget.xpAwarded} XP earned',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.leveledUp) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Level ${widget.newLevel}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        // Streak callout
        if (widget.newStreak > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  '${widget.newStreak}-day streak!',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
        // New badge chips
        if (widget.newBadges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: widget.newBadges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.military_tech_rounded,
                        color: Color(0xFFFBBF24), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      badge,
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
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
                style: TextStyle(
                  color: _scoreColor(skill.score),
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
    if (widget.config.insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('—',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 14)),
        ),
      );
    }
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
    if (widget.config.improvements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('—',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 14)),
        ),
      );
    }
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

  // ─── Recommended Next Card ───────────────────────────────────────────────────

  Widget _buildRecommendedNextCard(BuildContext context) {
    final nextType = widget.report!.recommendedNextType!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RoleplaySetupScreen(mode: 'prefilled', scenario: nextType),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryLight,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try next:',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nextType,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 14),
          ],
        ),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoleplaySetupScreen(mode: 'custom')),
                );
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

}

// ─── Custom Painter: Score Ring ───────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color lightColor;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.lightColor,
  });

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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Secondary lighter arc (small accent)
    final lightPaint = Paint()
      ..color = lightColor
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
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
