
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/commitment_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class GoalConfirmationScreen extends StatefulWidget {
  const GoalConfirmationScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<GoalConfirmationScreen> createState() =>
      _GoalConfirmationScreenState();
}

class _GoalConfirmationScreenState extends State<GoalConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selected = {};
  late AnimationController _entranceCtrl;

  static const _goals = [
    _Goal(
      label: 'Confidence',
      tagline: 'Stop second-guessing every word you say',
      icon: Icons.emoji_events_rounded,
      accent: Color(0xFFF59E0B),
      gradient: [Color(0xFF221A0C), Color(0xFF0D1525)],
    ),
    _Goal(
      label: 'Clarity',
      tagline: 'Say exactly what you mean, every single time',
      icon: Icons.record_voice_over_rounded,
      accent: Color(0xFF38BDF8),
      gradient: [Color(0xFF0C2233), Color(0xFF0D1525)],
    ),
    _Goal(
      label: 'Tough Conversations',
      tagline: 'Face the hard talks without backing down',
      icon: Icons.shield_rounded,
      accent: Color(0xFF818CF8),
      gradient: [Color(0xFF130D2E), Color(0xFF0D1525)],
    ),
    _Goal(
      label: 'Public Speaking',
      tagline: 'Command attention the moment you start',
      icon: Icons.mic_external_on_rounded,
      accent: Color(0xFF5B52F0),
      gradient: [Color(0xFF0F0C2A), Color(0xFF0D1525)],
    ),
    _Goal(
      label: 'Persuasion',
      tagline: 'Get people to genuinely believe in your ideas',
      icon: Icons.handshake_rounded,
      accent: Color(0xFF10B981),
      gradient: [Color(0xFF0C221A), Color(0xFF0D1525)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnim(int index) {
    final start = (index / _goals.length) * 0.50;
    final end = (start + 0.50).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  void _finish() {
    final goalString = _selected.join(', ');
    final fullData = widget.data.copyWith(primaryGoal: goalString);
    debugPrint('[Onboarding] Step 6/6 — Goals: "$goalString"');
    Navigator.push(
      context,
      slideRoute(CommitmentScreen(data: fullData)),
    );
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

                buildOnboardingHeader(context, 5),

                const SizedBox(height: 28),

                // Header
                const Text(
                  'One last thing —',
                  style: TextStyle(
                    color: AppColors.brandLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What matters\nmost to you?',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Pick all that apply — we'll build your plan around them",
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),

                // Goal cards
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final goal = _goals[i];
                      final anim = _itemAnim(i);
                      return AnimatedBuilder(
                        animation: _entranceCtrl,
                        builder: (_, child) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _GoalCard(
                          goal: goal,
                          isSelected: _selected.contains(goal.label),
                          onTap: () => setState(() {
                            if (_selected.contains(goal.label)) {
                              _selected.remove(goal.label);
                            } else {
                              _selected.add(goal.label);
                            }
                          }),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                OnboardingButton(
                  label: _selected.isEmpty
                      ? 'Begin My Journey'
                      : _selected.length == 1
                          ? 'Begin My Journey'
                          : 'Begin My Journey (${_selected.length} goals)',
                  enabled: _selected.isNotEmpty,
                  onPressed: _finish,
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
// Goal Card
// ─────────────────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final _Goal goal;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandLight.withValues(alpha: 0.55)
                : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.18)
                    : const Color(0xFF131D2E),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                goal.icon,
                color: isSelected ? AppColors.brandLight : AppColors.inkSoft,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.tagline,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.inkMuted
                          : AppColors.inkSoft,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.brand : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.outline,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.inkOnDark, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Goal {
  final String label;
  final String tagline;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;
  const _Goal({
    required this.label,
    required this.tagline,
    required this.icon,
    required this.accent,
    required this.gradient,
  });
}
