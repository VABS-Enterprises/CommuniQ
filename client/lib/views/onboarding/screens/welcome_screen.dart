import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/auth/screens/login_screen.dart';
import 'package:communiq/views/onboarding/screens/communication_context_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // Looping orb pulse — one gentle breathing glow, nothing more.
  late AnimationController _orbCtrl;
  // One-shot entrance
  late AnimationController _entranceCtrl;

  late Animation<double> _orbScale;
  late Animation<double> _orbGlowAlpha;

  late Animation<double> _fadeLogo;
  late Animation<double> _scaleOrb;
  late Animation<double> _fadeTitle;
  late Animation<Offset> _slideTitle;
  late Animation<double> _fadeSub;
  late Animation<Offset> _slideSub;
  late Animation<double> _fadeStats;
  late Animation<double> _fadeBtn;
  late Animation<Offset> _slideBtn;

  @override
  void initState() {
    super.initState();

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Orb pulse — subtle scale + glow-intensity breathing, no ring stack.
    _orbScale = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));
    _orbGlowAlpha = Tween<double>(begin: 0.28, end: 0.5)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

    // Entrance animations (staggered)
    _fadeLogo = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut));
    _scaleOrb = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)));

    _fadeTitle = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.60, curve: Curves.easeOut));
    _slideTitle = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 0.60, curve: Curves.easeOut)));

    _fadeSub = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut));
    _slideSub = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.35, 0.70, curve: Curves.easeOut)));

    _fadeStats = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.5, 0.80, curve: Curves.easeOut));

    _fadeBtn = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOut));
    _slideBtn = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.60, 1.0, curve: Curves.easeOut)));
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: OnboardingBackground(
        // Same two-orb ambient background every other onboarding screen
        // uses — replaces this screen's old, much busier three-blob
        // animated background (one of which sat behind the CTA button).
        child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Orb
                  FadeTransition(
                    opacity: _fadeLogo,
                    child: ScaleTransition(
                      scale: _scaleOrb,
                      child: AnimatedBuilder(
                        animation: _orbCtrl,
                        builder: (_, __) => _buildOrb(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Headline
                  FadeTransition(
                    opacity: _fadeTitle,
                    child: SlideTransition(
                      position: _slideTitle,
                      child: const Text(
                          'Speak It Like You\nMean It',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            // Was Colors.white — the app's headline, drawn in
                            // white on the cream ground, so the first thing a
                            // new user saw was blank space.
                            color: AppColors.ink,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                            letterSpacing: -0.8,
                          ),
                        ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tagline
                  FadeTransition(
                    opacity: _fadeSub,
                    child: SlideTransition(
                      position: _slideSub,
                      child: const Text(
                        'Master real conversations with\nAI-powered voice practice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 16,
                          height: 1.65,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Stats
                  FadeTransition(
                    opacity: _fadeStats,
                    child: _buildStatsRow(),
                  ),

                  const Spacer(flex: 2),

                  // CTA
                  FadeTransition(
                    opacity: _fadeBtn,
                    child: SlideTransition(
                      position: _slideBtn,
                      child: OnboardingButton(
                        label: 'Begin Your Journey',
                        onPressed: () => Navigator.push(
                          context,
                          slideRoute(const CommunicationContextScreen()),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  FadeTransition(
                    opacity: _fadeBtn,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        slideRoute(const LoginScreen()),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: 'Already training? ',
                          style: TextStyle(
                              color: AppColors.inkSoft, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: AppColors.brandLight,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.brandLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
        ),
      ),
    );
  }

  // ── Orb ────────────────────────────────────────────────────────────────────

  // One circular icon, one soft ambient glow behind it, a gentle breathing
  // pulse on that glow's intensity. That's it — no stacked concentric rings.
  Widget _buildOrb() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Center(
        child: Transform.scale(
          scale: _orbScale.value,
          child: Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brand,
              border: Border.all(
                color: AppColors.brandLight.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: _orbGlowAlpha.value),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/hummingbird.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat('10K+', 'Learners'),
          _buildDivider(),
          _buildStat('6', 'Skills Scored'),
          _buildDivider(),
          _buildStat('95%', 'Improve Fast'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.brandLight,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.outline,
    );
  }
}
