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
      backgroundColor: AppColors.background,
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
                          color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.62,
                          ),
                          children: [
                            const TextSpan(text: 'The struggle with '),
                            TextSpan(
                              text: _challenge(),
                              style: const TextStyle(
                                color: AppColors.primaryLight,
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
                          stat: '7/10',
                          label: 'struggle with self-\nexpression daily',
                          icon: Icons.people_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Enter(
                        anim: _a(0.37, 0.69),
                        dy: 0.22,
                        child: _ProofCard(
                          stat: '83%',
                          label: 'say confidence\nchanged their career',
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Enter(
                        anim: _a(0.44, 0.76),
                        dy: 0.22,
                        child: _ProofCard(
                          stat: '2 wks',
                          label: 'average time to\nnotice real change',
                          icon: Icons.bolt_rounded,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── 4. Testimonials — swipeable cards with star ratings ─────
                _Enter(
                  anim: _a(0.50, 0.76),
                  child: const Text(
                    'WHAT OTHERS SAY',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                _Enter(
                  anim: _a(0.54, 0.88),
                  child: _TestimonialsCarousel(),
                ),

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
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The big number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: const [
                    Text(
                      '9',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 62,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -3,
                      ),
                    ),
                    SizedBox(width: 2),
                    Text(
                      '/10',
                      style: TextStyle(
                        color: Color(0x50FFFFFF),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'people held back what they really\nwanted to say — at least once this week.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
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
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.primaryLight, size: 15),
              ),
              const SizedBox(height: 10),
              // Stat number
              Text(
                stat,
                style: const TextStyle(
                  color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10.5,
                  height: 1.42,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Testimonials Carousel — horizontal swipeable review cards with star ratings
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewItem {
  const _ReviewItem({
    required this.initial,
    required this.avatarColors,
    required this.name,
    required this.meta,
    required this.quote,
    this.stars = 5,
  });

  final String initial;
  final List<Color> avatarColors;
  final String name;
  final String meta;
  final String quote;
  final int stars;
}

class _TestimonialsCarousel extends StatefulWidget {
  @override
  State<_TestimonialsCarousel> createState() => _TestimonialsCarouselState();
}

/// Uses an [AnimationController] (vsync'd to the display refresh) to drive
/// a [ScrollController] frame-by-frame via [jumpTo].  A 100× item repeat
/// gives ~50 minutes of scroll before the silent reset — invisible to the user.
class _TestimonialsCarouselState extends State<_TestimonialsCarousel>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollCtrl;
  late final AnimationController _animCtrl;

  // Pixels scrolled per second
  static const double _speed = 52.0;
  // How many times to repeat the data list for the seamless buffer
  static const int _repeatCount = 100;

  // Width of exactly one full pass of all cards (computed from MediaQuery)
  double _singleSetWidth = 0;
  bool _started = false;

  static const _reviews = [
    _ReviewItem(
      initial: 'P',
      avatarColors: [AppColors.primary, AppColors.primaryLight],
      name: 'Priya S.',
      meta: '26 · Marketing Manager',
      quote:
          'I used to go quiet in every group discussion. Three weeks in, I was the one leading them.',
    ),
    _ReviewItem(
      initial: 'R',
      avatarColors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      name: 'Rohan M.',
      meta: '29 · Product Manager',
      quote:
          'Went from dreading presentations to actually looking forward to them.',
    ),
    _ReviewItem(
      initial: 'A',
      avatarColors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      name: 'Aisha K.',
      meta: '24 · Software Engineer',
      quote:
          'Stopped second-guessing every word I said — within just two weeks.',
    ),
    _ReviewItem(
      initial: 'K',
      avatarColors: [Color(0xFF10B981), Color(0xFF059669)],
      name: 'Karan V.',
      meta: '31 · Sales Lead',
      quote:
          'My confidence in client calls went from 3/10 to 9/10. Night and day.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    // Placeholder duration — updated in didChangeDependencies once we have
    // the screen width to compute _singleSetWidth.
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    _animCtrl.addListener(_driveScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cardWidth = MediaQuery.of(context).size.width - 86;
    // Each item slot = card width + 10 px gap on the right
    _singleSetWidth = _reviews.length * (cardWidth + 10);

    if (!_started) {
      _started = true;
      // Set the real duration: time to traverse one full set at constant speed
      _animCtrl.duration = Duration(
        milliseconds: (_singleSetWidth / _speed * 1000).round(),
      );
      // Start after entrance animations finish
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) _animCtrl.repeat();
      });
    }
  }

  /// Called every display frame by [_animCtrl].
  /// Maps controller value (0 → 1) to scroll offset (0 → _singleSetWidth).
  /// When the controller repeats (value resets to 0), the scroll jumps back
  /// to 0 — which is visually seamless because the buffer is identical.
  void _driveScroll() {
    if (!_scrollCtrl.hasClients || _singleSetWidth == 0) return;
    _scrollCtrl.jumpTo(_animCtrl.value * _singleSetWidth);
  }

  @override
  void dispose() {
    _animCtrl
      ..removeListener(_driveScroll)
      ..dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 86;
    return SizedBox(
      height: 124,
      child: ListView.builder(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        // Programmatic-only scroll — no user gesture interference
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _reviews.length * _repeatCount,
        itemBuilder: (context, index) {
          final item = _reviews[index % _reviews.length];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: cardWidth,
              child: _ReviewCard(item: item),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});
  final _ReviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stars + name row ──
          Row(
            children: [
              // Amber star rating
              Row(
                children: List.generate(
                  item.stars,
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                      size: 14,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Name chip
              Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Quote ──
          Expanded(
            child: Text(
              '"${item.quote}"',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.48,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // ── Avatar + meta ──
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.meta,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Back button
// ─────────────────────────────────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
