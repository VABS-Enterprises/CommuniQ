import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class RoleplayIntroScreen extends StatefulWidget {
  const RoleplayIntroScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<RoleplayIntroScreen> createState() => _RoleplayIntroScreenState();
}

class _RoleplayIntroScreenState extends State<RoleplayIntroScreen>
    with TickerProviderStateMixin {
  // Mic pulse loop
  late AnimationController _pulseCtrl;
  // Wave rings
  late AnimationController _waveCtrl;
  // One-shot entrance
  late AnimationController _entranceCtrl;

  late Animation<double> _micScale;
  late Animation<double> _micGlow;
  late Animation<double> _fadeContent;
  late Animation<Offset> _slideContent;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _micScale = Tween<double>(begin: 0.93, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _micGlow = Tween<double>(begin: 0.3, end: 0.6).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeContent = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _slideContent = Tween<Offset>(
            begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToSignup() async {
    debugPrint('[Onboarding] Step 6/6 — Completing onboarding → Signup');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    await OnboardingService.saveLocally(widget.data);
    if (!mounted) return;
    Navigator.push(
      context,
      slideRoute(SignupScreen(onboardingData: widget.data)),
    );
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
              children: [
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 6),

                const Spacer(flex: 1),

                // Animated mic visualization
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _waveCtrl]),
                  builder: (_, __) => _buildMicVisual(),
                ),

                const SizedBox(height: 32),

                // Content
                FadeTransition(
                  opacity: _fadeContent,
                  child: SlideTransition(
                    position: _slideContent,
                    child: Column(
                      children: [
                        const Text(
                          'Your first roleplay\nawaits',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Practice with a real scenario the moment\nyou create your account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 28),

                        _buildScenarioCard(),

                        const SizedBox(height: 16),

                        // Feature pills
                        _buildFeatureRow(),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                OnboardingButton(
                  label: "Let's Get a Demo",
                  showGradient: false,
                  onPressed: _goToSignup,
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _goToSignup,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text(
                    'Skip for now →',
                    style: TextStyle(fontSize: 14),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mic Visual ─────────────────────────────────────────────────────────────

  Widget _buildMicVisual() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding wave rings
          ...[0.0, 0.33, 0.66].map((offset) {
            final t = ((_waveCtrl.value + offset) % 1.0);
            final scale = 0.5 + t * 0.9;
            final alpha = (1.0 - t) * 0.25;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: alpha),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),

          // Core mic button
          Transform.scale(
            scale: _micScale.value,
              child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _micGlow.value),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scenario Card ──────────────────────────────────────────────────────────

  Widget _buildScenarioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SCENARIO',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.lock_open_rounded,
                  color: AppColors.success, size: 14),
              const SizedBox(width: 4),
              const Text(
                'Unlocked',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Introduce yourself',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us about yourself in a relaxed, friendly conversation. '
            'A great place to start your journey.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildChip(Icons.face_retouching_natural_rounded, 'Friendly AI'),
              const SizedBox(width: 8),
              _buildChip(Icons.timer_outlined, '2 min'),
              const SizedBox(width: 8),
              _buildChip(Icons.bar_chart_rounded, 'Beginner'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature Row ────────────────────────────────────────────────────────────

  Widget _buildFeatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFeaturePill(Icons.insights_rounded, 'AI scoring'),
        const SizedBox(width: 8),
        _buildFeaturePill(Icons.replay_rounded, 'Instant replay'),
        const SizedBox(width: 8),
        _buildFeaturePill(Icons.lightbulb_rounded, 'Live tips'),
      ],
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.violetLight, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
