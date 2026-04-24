import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/roleplay_intro_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

/// Social proof + transformation screen shown after Level Selection.
/// Slot: between LevelSelectionScreen and RoleplayIntroScreen.
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

  String _testimonial() {
    switch (widget.data.level) {
      case 'Intermediate':
        return 'I used to panic when a client asked something unexpected. Now I actually enjoy those moments.';
      case 'Advanced':
        return 'I thought I was already good at communicating. CommuniQ showed me the difference between good and unforgettable.';
      default:
        return 'After 3 weeks, I got a callback from every company I interviewed with. I couldn\'t believe the difference.';
    }
  }

  String _testimonialPerson() {
    switch (widget.data.level) {
      case 'Intermediate':
        return 'Rohan M. · 29 · Product Manager';
      case 'Advanced':
        return 'Sneha K. · 31 · Senior Consultant';
      default:
        return 'Arjun P. · 23 · Software Engineer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = _getPairs();
    final level = widget.data.level ?? 'Beginner';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Back + frozen progress (step 4 complete)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _backButton(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: buildProgressBar(4)),
                  ],
                ),

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
                          "Here's what changes\nin 3 weeks",
                          style: TextStyle(
                            color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
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

                // ── Testimonial ────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.50, 0.90),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.50, 0.90)),
                    child: _buildTestimonial(),
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
                        slideRoute(RoleplayIntroScreen(data: widget.data)),
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
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
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
                          color: AppColors.textMuted,
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
                        'After 3 weeks',
                        style: TextStyle(
                          color: AppColors.textMuted,
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
                                  color: AppColors.textMuted,
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
                                  color: AppColors.textPrimary,
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
                      color: AppColors.cardBorder,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 18)),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Testimonial ────────────────────────────────────────────────────────────

  Widget _buildTestimonial() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: AppColors.primaryLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _testimonial(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _testimonialPerson(),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  Widget _backButton() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.textSecondary,
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
