import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/speaking_style_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

/// Emotional validation screen shown after the user admits their challenges.
/// Slot: between PersonalChallengesScreen and SpeakingStyleScreen.
class ValidationScreen extends StatefulWidget {
  const ValidationScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends State<ValidationScreen>
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

  // Pick the most emotionally resonant challenge the user selected
  String _firstChallenge() {
    final c = widget.data.challenges;
    if (c.isEmpty) return 'holding back in conversations';
    // Map raw labels to more emotional phrasings
    const map = {
      'Feeling nervous': 'feeling nervous before speaking',
      'Running out of words': 'running out of words mid-conversation',
      'Speaking too fast or slow': 'losing control of your pace',
      'Avoiding difficult talks': 'avoiding the hard conversations',
      'Not expressing clearly': 'struggling to express yourself clearly',
      'Ideas get lost in translation': 'ideas getting lost in translation',
      'Lack of confidence': 'lacking confidence in your voice',
      'Being interrupted or talked over': 'being interrupted or talked over',
    };
    return map[c.first] ?? c.first.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
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

                // Back + frozen progress (step 2 complete)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _backButton(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: buildProgressBar(2)),
                  ],
                ),

                const Spacer(flex: 1),

                // ── Big stat ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.0, 0.45),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.0, 0.45)),
                    child: _buildStatHero(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Headline ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.15, 0.55),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.15, 0.55)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "You're not alone\nin this.",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              height: 1.65,
                            ),
                            children: [
                              const TextSpan(text: 'The struggle with '),
                              TextSpan(
                                text: _firstChallenge(),
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                  text:
                                      ' is one of the most common things we hear. And it\'s one of the fastest to fix.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Truth pills ────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.3, 0.70),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.3, 0.70)),
                    child: _buildTruthPills(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Testimonial ────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.5, 0.90),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.2), end: Offset.zero)
                        .animate(_anim(0.5, 0.90)),
                    child: _buildTestimonial(),
                  ),
                ),

                const Spacer(flex: 2),

                // ── CTA ────────────────────────────────────────────────────
                FadeTransition(
                  opacity: _anim(0.65, 1.0),
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(_anim(0.65, 1.0)),
                    child: OnboardingButton(
                      label: "I'm ready to change this",
                      onPressed: () => Navigator.push(
                        context,
                        slideRoute(SpeakingStyleScreen(data: widget.data)),
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

  // ── Stat Hero ──────────────────────────────────────────────────────────────

  Widget _buildStatHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          // Large number
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: AppColors.primaryGradient,
            ).createShader(b),
            blendMode: BlendMode.srcIn,
            child: const Text(
              '9/10',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'people say they\'ve held back what they really wanted to say — at least once this week.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Truth Pills ────────────────────────────────────────────────────────────

  Widget _buildTruthPills() {
    const items = [
      'Communication is a skill — not a personality trait',
      'Skills are trained, not inherited',
      'Most people improve noticeably in under 2 weeks',
    ];

    return Column(
      children: items.map((text) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.primaryLight,
                  size: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              color: AppColors.primaryLight, size: 22),
          const SizedBox(height: 8),
          const Text(
            'I used to go completely quiet in group discussions. Three weeks in, I was the one leading them.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primaryLight, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Priya S. · 26 · Marketing Manager',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
