import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/services/onboarding_service.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/auth/screens/signup_screen.dart';
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

  // Building phase — orb pulse + sequential item appearance
  late AnimationController _orbCtrl;
  late AnimationController _buildItemsCtrl;

  // Reveal phase — staggered entrance
  late AnimationController _revealCtrl;

  late Animation<double> _orbScale;
  late Animation<double> _orbGlow;

  static const _buildDuration = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _buildItemsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _orbScale = Tween<double>(begin: 0.94, end: 1.06)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));
    _orbGlow = Tween<double>(begin: 0.25, end: 0.50)
        .animate(CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut));

    // Switch to reveal phase after building completes
    Future.delayed(_buildDuration, () {
      if (!mounted) return;
      setState(() => _phase = _Phase.revealed);
      _revealCtrl.forward();
    });
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _buildItemsCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    await OnboardingService.saveLocally(widget.data);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      slideRoute(SignupScreen(onboardingData: widget.data)),
      (_) => false,
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
                    orbCtrl: _orbCtrl,
                    itemsCtrl: _buildItemsCtrl,
                    orbScale: _orbScale,
                    orbGlow: _orbGlow,
                    data: widget.data,
                  )
                : _RevealView(
                    key: const ValueKey('revealed'),
                    revealCtrl: _revealCtrl,
                    data: widget.data,
                    onContinue: _goToSignup,
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

class _BuildingView extends StatelessWidget {
  final AnimationController orbCtrl;
  final AnimationController itemsCtrl;
  final Animation<double> orbScale;
  final Animation<double> orbGlow;
  final OnboardingData data;

  const _BuildingView({
    super.key,
    required this.orbCtrl,
    required this.itemsCtrl,
    required this.orbScale,
    required this.orbGlow,
    required this.data,
  });

  static const _steps = [
    'Analyzing your communication style',
    'Mapping your challenges',
    'Calibrating difficulty level',
    'Preparing your first session',
  ];

  Animation<double> _stepAnim(int i, AnimationController ctrl) {
    final start = i * 0.22;
    final end = (start + 0.30).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Animated orb
          AnimatedBuilder(
            animation: orbCtrl,
            builder: (_, __) => _buildOrb(),
          ),

          const SizedBox(height: 36),

          const Text(
            'Building your plan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Personalizing everything to you',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 44),

          // Sequential build steps
          AnimatedBuilder(
            animation: itemsCtrl,
            builder: (_, __) => Column(
              children: List.generate(_steps.length, (i) {
                final anim = _stepAnim(i, itemsCtrl);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.primaryLight,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            _steps[i],
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildOrb() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Transform.scale(
            scale: orbScale.value * 1.15,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Core
          Transform.scale(
            scale: orbScale.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: orbGlow.value),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 2 — Plan Revealed
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedBuilder(
        animation: revealCtrl,
        builder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),

            // Header
            FadeTransition(
              opacity: _anim(0.0, 0.5),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.2), end: Offset.zero)
                    .animate(_anim(0.0, 0.5)),
                child: _buildHeader(),
              ),
            ),

            const SizedBox(height: 28),

            // Plan summary card
            FadeTransition(
              opacity: _anim(0.2, 0.7),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.2), end: Offset.zero)
                    .animate(_anim(0.2, 0.7)),
                child: _buildPlanCard(),
              ),
            ),

            const SizedBox(height: 16),

            // Week 1 preview card
            FadeTransition(
              opacity: _anim(0.4, 0.85),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.2), end: Offset.zero)
                    .animate(_anim(0.4, 0.85)),
                child: _buildWeek1Card(),
              ),
            ),

            const Spacer(),

            // CTA
            FadeTransition(
              opacity: _anim(0.65, 1.0),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.3), end: Offset.zero)
                    .animate(_anim(0.65, 1.0)),
                child: Column(
                  children: [
                    OnboardingButton(
                      label: 'Create Your Free Account',
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
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 14),
              SizedBox(width: 6),
              Text(
                'Plan ready',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "Here's what we built\nfor you",
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
          'Personalized based on your answers',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ── Plan Summary Card ──────────────────────────────────────────────────────

  Widget _buildPlanCard() {
    final goal = data.primaryGoal ?? 'Communication';
    final level = data.level ?? 'Beginner';
    final contexts = data.contexts.take(3).toList();

    final levelColor = _levelColor(level);
    final goalIcon = _goalIcon(goal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          const Text(
            'YOUR TRAINING PLAN',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Goal row
          _planRow(
            icon: goalIcon,
            iconBg: AppColors.primary.withValues(alpha: 0.15),
            iconColor: AppColors.primaryLight,
            label: 'Primary Goal',
            value: goal,
          ),

          const SizedBox(height: 2),
          _divider(),
          const SizedBox(height: 2),

          // Level row
          _planRow(
            icon: Icons.trending_up_rounded,
            iconBg: levelColor.withValues(alpha: 0.15),
            iconColor: levelColor,
            label: 'Starting Level',
            value: level,
          ),

          if (contexts.isNotEmpty) ...[
            const SizedBox(height: 2),
            _divider(),
            const SizedBox(height: 12),

            // Focus areas
            const Text(
              'Focus areas',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: contexts
                  .map((c) => _contextChip(c))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 1, color: AppColors.cardBorder);
  }

  Widget _contextChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Week 1 Preview Card ────────────────────────────────────────────────────

  Widget _buildWeek1Card() {
    final level = data.level ?? 'Beginner';
    final goal = data.primaryGoal ?? 'Communication';

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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Week 1 Preview',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_sessionsLabel(data.commitmentDays)} · $level difficulty · $goal focused',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _weekPill(Icons.mic_rounded, 'Voice sessions'),
                    const SizedBox(width: 8),
                    _weekPill(Icons.insights_rounded, 'AI scoring'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekPill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  String _sessionsLabel(int? days) {
    switch (days) {
      case 2:
        return '2 sessions / week';
      case 5:
        return '5 sessions / week';
      default:
        return '3 sessions / week';
    }
  }

  IconData _goalIcon(String goal) {
    switch (goal) {
      case 'Confidence':
        return Icons.emoji_events_rounded;
      case 'Clarity':
        return Icons.record_voice_over_rounded;
      case 'Tough Conversations':
        return Icons.shield_rounded;
      case 'Public Speaking':
        return Icons.mic_external_on_rounded;
      case 'Persuasion':
        return Icons.handshake_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
