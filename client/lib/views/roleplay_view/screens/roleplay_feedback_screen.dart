import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/models/feedback_config.dart';
import 'package:communiq/models/session_result_model.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/core/data/scenario_presets.dart';
import 'package:communiq/views/onboarding/screens/goal_confirmation_screen.dart';
import 'package:communiq/views/roleplay_view/screens/setup_scenario_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
// One set of constants so every colour decision is in one place.

const _kBarColor = AppColors.primary;          // indigo — all skill bars
const _kTrackColor = Color(0xFF1E293B);         // dark slate track
const _kCardBg = Color(0xFF0F172A);             // surface card
const _kDivider = Color(0xFF1E293B);            // subtle divider
const _kUserLabel = AppColors.primary;
const _kAiLabel = Color(0xFF475569);            // slate-600

// ─── Screen ────────────────────────────────────────────────────────────────────

class RoleplayFeedbackScreen extends StatefulWidget {
  final FeedbackConfig config;
  final SessionReport? report;

  /// Turn-by-turn history — [{role: 'user'|'ai', transcript: '...'}]
  final List<Map<String, String>> conversationHistory;

  final bool isOnboarding;
  final int xpAwarded;
  final int newLevel;
  final bool leveledUp;
  final List<String> newBadges;
  final int newStreak;

  const RoleplayFeedbackScreen({
    super.key,
    required this.config,
    this.report,
    this.conversationHistory = const [],
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
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  late List<AnimationController> _barCtrl;
  late List<Animation<double>> _barAnim;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _ringAnim = Tween<double>(begin: 0, end: widget.config.overallScore / 100)
        .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic));

    _barCtrl = List.generate(widget.config.skills.length,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 800)));
    _barAnim = List.generate(
      widget.config.skills.length,
      (i) => Tween<double>(begin: 0, end: widget.config.skills[i].score / 100)
          .animate(CurvedAnimation(
              parent: _barCtrl[i], curve: Curves.easeOutCubic)),
    );

    _ringCtrl.forward();
    for (int i = 0; i < _barCtrl.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 120),
          () { if (mounted) _barCtrl[i].forward(); });
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    for (final c in _barCtrl) { c.dispose(); }
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _scoreLabel(int s) {
    if (s >= 90) return 'Outstanding';
    if (s >= 75) return 'Great Job';
    if (s >= 60) return 'Good Start';
    if (s >= 45) return 'Keep Practicing';
    return 'Room to Grow';
  }

  /// Best-effort match of a free-form scenario name (the evaluator's
  /// `recommendedNextType`, or this session's own title) back to a real
  /// [ScenarioPreset] key, so "Recommended next" / "Practice again" can
  /// prefill [SetupScenarioPage] instead of opening it blank. Returns null
  /// — which [SetupScenarioPage] already treats as "open in custom mode" —
  /// when nothing matches, rather than guessing wrong.
  String? _matchPresetKey(String candidate) {
    final exact = presetForKey(candidate);
    if (exact != null) return exact.key;
    final needle = candidate.trim().toLowerCase();
    for (final p in kScenarioPresets) {
      if (p.title.toLowerCase() == needle) return p.key;
    }
    return null;
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Score hero
                    _scoreHero(),
                    const SizedBox(height: AppSpacing.s28),

                    // 2. Skill breakdown — compact rows
                    _sectionLabel('SKILL BREAKDOWN'),
                    const SizedBox(height: AppSpacing.s12),
                    _skillRows(),
                    const SizedBox(height: AppSpacing.s28),

                    // 3. Conversation transcript — inline on the page
                    _sectionLabel('CONVERSATION'),
                    const SizedBox(height: AppSpacing.s4),
                    const Text(
                      'Tap highlighted words for feedback.',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _transcriptBlock(),
                    const SizedBox(height: AppSpacing.s28),

                    // 4. Coach insights
                    _sectionLabel('AI COACH INSIGHTS'),
                    const SizedBox(height: AppSpacing.s12),
                    _insightsCard(),
                    const SizedBox(height: AppSpacing.s28),

                    // 5. Improve next time
                    _sectionLabel('IMPROVE NEXT TIME'),
                    const SizedBox(height: AppSpacing.s12),
                    _improvementsCard(),

                    // 6. Recommended next (optional)
                    if (widget.report?.recommendedNextType != null) ...[
                      const SizedBox(height: AppSpacing.s28),
                      _sectionLabel('RECOMMENDED NEXT'),
                      const SizedBox(height: AppSpacing.s12),
                      _recommendedCard(context),
                    ],

                    const SizedBox(height: AppSpacing.s32),
                    _bottomActions(context),
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

  // ─── Top bar ─────────────────────────────────────────────────────────────────

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kDivider),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 16),
            ),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            padding: EdgeInsets.zero,
          ),
          const Expanded(
            child: Text(
              'Session Complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ─── Score hero ──────────────────────────────────────────────────────────────
  // Compact row: ring on left, title + label + XP chips on right.

  Widget _scoreHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Ring ─────────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) {
              final v = _ringAnim.value;
              final score = widget.config.overallScore;
              final display = (v * score).round();
              return SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _RingPainter(progress: v),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$display',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        const Text(
                          '%',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
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
          const SizedBox(width: 20),

          // ── Right side ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SESSION PERFORMANCE',
                    style: TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.config.scenarioTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _scoreLabel(widget.config.overallScore),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // XP + streak chips
                if (widget.xpAwarded > 0 ||
                    widget.newStreak > 0 ||
                    widget.newBadges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (widget.xpAwarded > 0)
                        _chip(
                          icon: Icons.bolt_rounded,
                          label: '+${widget.xpAwarded} XP',
                          color: AppColors.primaryLight,
                        ),
                      if (widget.leveledUp)
                        _chip(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Level ${widget.newLevel}',
                          color: AppColors.primaryLight,
                        ),
                      if (widget.newStreak > 0)
                        _chip(
                          emoji: '🔥',
                          label: '${widget.newStreak}-day streak',
                          color: AppColors.scoreNeedsWork,
                        ),
                      ...widget.newBadges.map((b) => _chip(
                            icon: Icons.military_tech_rounded,
                            label: b,
                            color: AppColors.scoreNeedsWork,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    IconData? icon,
    String? emoji,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji, style: const TextStyle(fontSize: 11))
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section label ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Skill rows ───────────────────────────────────────────────────────────────
  // Flat table-style rows — single indigo bar, no colour coding by score.
  // The score percentage as text is enough information; colour-coded bars
  // are visually noisy and redundant.

  Widget _skillRows() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        children: List.generate(widget.config.skills.length, (i) {
          final skill = widget.config.skills[i];
          final isLast = i == widget.config.skills.length - 1;
          return Column(
            children: [
              _skillRow(skill, _barAnim[i]),
              if (!isLast) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: _kDivider),
                const SizedBox(height: 14),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _skillRow(SkillCard skill, Animation<double> anim) {
    return Row(
      children: [
        // Name
        Expanded(
          flex: 4,
          child: Text(
            skill.title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Bar — single indigo, no gradients, no shadows
        Expanded(
          flex: 5,
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Container(color: _kTrackColor),
                    FractionallySizedBox(
                      widthFactor: anim.value,
                      alignment: Alignment.centerLeft,
                      child: Container(color: _kBarColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Score number — right-aligned, fixed width so bars align
        SizedBox(
          width: 36,
          child: Text(
            '${skill.score}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Conversation transcript ──────────────────────────────────────────────────

  Widget _transcriptBlock() {
    final history = widget.conversationHistory;
    final rawTranscript = widget.report?.rawTranscript ?? '';
    final fillerSet =
        widget.report?.fillerWords.map((w) => w.toLowerCase()).toSet() ??
            <String>{};

    if (history.isEmpty && rawTranscript.isEmpty) {
      return _emptyCard('Transcript not available.');
    }

    if (history.isEmpty) {
      // Fallback: show raw string
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDivider),
        ),
        child: Text(
          rawTranscript,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.7),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        children: history.asMap().entries.map((e) {
          final i = e.key;
          final turn = e.value;
          final isUser = (turn['role'] ?? '') == 'user';
          final text = turn['transcript'] ?? '';
          final isLast = i == history.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role badge
                    Container(
                      width: 36,
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        isUser ? 'YOU' : 'AI',
                        style: TextStyle(
                          color: isUser ? _kUserLabel : _kAiLabel,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: isUser
                          ? _userText(text, fillerSet)
                          : Text(
                              text,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.65,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: _kDivider, indent: 14, endIndent: 14),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Renders user text with filler words underlined red (tappable).
  Widget _userText(String text, Set<String> fillerSet) {
    if (text.isEmpty) return const SizedBox.shrink();
    final words = text.split(RegExp(r'\s+'));
    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final clean = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
      final isFiller = fillerSet.contains(clean);

      if (isFiller) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showTooltip('"$word" is a filler word — try pausing instead.');
            },
            child: Text(
              i < words.length - 1 ? '$word ' : word,
              style: const TextStyle(
                color: Color(0xFFF87171),
                fontSize: 13,
                height: 1.65,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFF87171),
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: i < words.length - 1 ? '$word ' : word,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.65,
          ),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showTooltip(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: const Color(0xFF1E293B),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Insights card ────────────────────────────────────────────────────────────

  Widget _insightsCard() {
    if (widget.config.insights.isEmpty) return _emptyCard('—');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        children: widget.config.insights.asMap().entries.map((e) {
          final isLast = e.key == widget.config.insights.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.value,
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

  // ─── Improvements card ────────────────────────────────────────────────────────

  Widget _improvementsCard() {
    if (widget.config.improvements.isEmpty) return _emptyCard('—');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        children: widget.config.improvements.asMap().entries.map((e) {
          final isLast = e.key == widget.config.improvements.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.primaryLight, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
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

  // ─── Recommended next ─────────────────────────────────────────────────────────

  Widget _recommendedCard(BuildContext context) {
    final nextType = widget.report!.recommendedNextType!;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => SetupScenarioPage(
              prefilledPresetKey: _matchPresetKey(nextType)))),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primaryLight, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Try next',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(nextType,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted, size: 13),
          ],
        ),
      ),
    );
  }

  // ─── Bottom actions ───────────────────────────────────────────────────────────

  Widget _bottomActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.isOnboarding) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const GoalConfirmationScreen(data: OnboardingData())),
                (_) => false,
              );
            } else {
              // Prefill with this same scenario when it matches a known
              // preset (e.g. finishing "Job Interview" offers straight back
              // into a configured "Job Interview" setup); otherwise this
              // was a custom scenario and opens blank, same as before.
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SetupScenarioPage(
                    prefilledPresetKey:
                        _matchPresetKey(widget.config.scenarioTitle),
                  ),
                ),
              );
            }
          },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.isOnboarding ? 'Continue' : 'Practice Again',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.popUntil(context, (r) => r.isFirst);
          },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kDivider, width: 1.5),
            ),
            child: const Center(
              child: Text(
                'Try New Scenario',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _emptyCard(String msg) => Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDivider),
        ),
        child: Center(
          child: Text(msg,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14)),
        ),
      );
}

// ─── Score ring painter ───────────────────────────────────────────────────────
// Single indigo arc on a dark track. No glow, no gradient, no shadow.

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    const stroke = 8.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _kTrackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = _kBarColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
