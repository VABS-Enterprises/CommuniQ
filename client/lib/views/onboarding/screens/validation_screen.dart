import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/speaking_style_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

/// Emotional validation screen — slot: PersonalChallenges → SpeakingStyle.
///
/// Visual hierarchy:
///   Headline → personalized context → editorial 9/10 hero →
///   3-card proof grid → testimonial → CTA
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
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _a(double begin, double end) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  String _challenge() {
    final c = widget.data.challenges;
    if (c.isEmpty) return 'holding back in conversations';
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
      backgroundColor: AppColors.bg,
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 2),

                const SizedBox(height: 28),

                // ── 1. Headline — emotional hook, first thing eyes land on ─
                _Enter(
                  anim: _a(0.00, 0.36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You're not alone\nin this.",
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 9),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 14,
                            height: 1.62,
                          ),
                          children: [
                            const TextSpan(text: 'The struggle with '),
                            TextSpan(
                              text: _challenge(),
                              style: const TextStyle(
                                color: AppColors.brandLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' is one of the most common things we hear — and one of the fastest to fix.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // ── 2. Hero stat — raw editorial number, no card ───────────
                //    The "9" is the visual anchor of the entire screen.
                _Enter(
                  anim: _a(0.14, 0.50),
                  child: _HeroStat(),
                ),

                const SizedBox(height: 22),

                // ── 3. Proof grid — three staggered glass cards ────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Enter(
                        anim: _a(0.30, 0.62),
                        dy: 0.22,
                        child: _ProofCard(
                          stat: '20',
                          label: 'bite-sized\nlessons',
                          icon: Icons.menu_book_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Enter(
                        anim: _a(0.37, 0.69),
                        dy: 0.22,
                        child: _ProofCard(
                          stat: '6',
                          label: 'skills scored\nevery session',
                          icon: Icons.insights_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Enter(
                        anim: _a(0.44, 0.76),
                        dy: 0.22,
                        child: _ProofCard(
                          stat: '24/7',
                          label: 'AI partner to\npractise with',
                          icon: Icons.bolt_rounded,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Spacer(),

                // ── 5. CTA ─────────────────────────────────────────────────
                _Enter(
                  anim: _a(0.68, 1.00),
                  dy: 0.28,
                  child: OnboardingButton(
                    label: "I'm ready to change this",
                    onPressed: () => Navigator.push(
                      context,
                      slideRoute(SpeakingStyleScreen(data: widget.data)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Stat — editorial "9/10" with a gradient left-border accent
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accent bar
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're not alone.",
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Holding back what you really want to say is common.\nIt is a skill — and skills get better with practice.',
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                    height: 1.52,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Proof Card — glass tile with an icon, big stat, small label
// ─────────────────────────────────────────────────────────────────────────────

class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.stat,
    required this.label,
    required this.icon,
  });

  final String stat;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.outline,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon chip
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.brandLight, size: 15),
            ),
            const SizedBox(height: 10),
            // Stat number
            Text(
              stat,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 5),
            // Description
            Text(
              label,
              style: TextStyle(
                color: AppColors.inkMuted,
                fontSize: 10.5,
                height: 1.42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance animation wrapper — fade + slide up, one-shot
// ─────────────────────────────────────────────────────────────────────────────

class _Enter extends StatelessWidget {
  const _Enter({
    required this.anim,
    required this.child,
    this.dy = 0.18,
  });

  final Animation<double> anim;
  final Widget child;

  /// Slide distance as a fraction of the widget's own height.
  final double dy;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }
}
