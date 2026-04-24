
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/transformation_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late AnimationController _entranceCtrl;

  static const _levels = [
    _Level(
      label: 'Beginner',
      tagline: 'Just getting started',
      description:
          'Nerves are real. You want to speak with more ease and stop second-guessing every word.',
      icon: Icons.spa_rounded,
      filledBars: 1,
      accent: Color(0xFF10B981),
      gradient: [Color(0xFF0C221A), Color(0xFF0D1525)],
      badge: 'Start here',
    ),
    _Level(
      label: 'Intermediate',
      tagline: 'Building momentum',
      description:
          'You can hold a conversation but stumble under pressure, in interviews, or with new people.',
      icon: Icons.trending_up_rounded,
      filledBars: 2,
      accent: Color(0xFFF59E0B),
      gradient: [Color(0xFF221A0C), Color(0xFF0D1525)],
      badge: 'Most common',
    ),
    _Level(
      label: 'Advanced',
      tagline: 'Sharpening the edge',
      description:
          'You communicate well. Now you want to be truly compelling — the kind of person people remember.',
      icon: Icons.local_fire_department_rounded,
      filledBars: 3,
      accent: Color(0xFF818CF8),
      gradient: [Color(0xFF130D2E), Color(0xFF0D1525)],
      badge: 'Go further',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _cardAnim(int index) {
    final start = (index / _levels.length) * 0.45;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                buildOnboardingHeader(context, 4),

                const SizedBox(height: 28),

                const Text(
                  'Where are you\nright now?',
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
                  "We'll calibrate your experience to match",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: List.generate(_levels.length, (i) {
                      final lvl = _levels[i];
                      final anim = _cardAnim(i);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedBuilder(
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
                          child: _LevelCard(
                            level: lvl,
                            isSelected: _selected == lvl.label,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = lvl.label);
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 8),

                OnboardingButton(
                  label: 'Continue',
                  enabled: _selected != null,
                  onPressed: () {
                    debugPrint(
                        '[Onboarding] Step 4/6 — Level: "$_selected"');
                    Navigator.push(
                      context,
                      slideRoute(TransformationScreen(
                        data: widget.data.copyWith(level: _selected!),
                      )),
                    );
                  },
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
// Level Card
// ─────────────────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final _Level level;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight.withValues(alpha: 0.55)
                : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : const Color(0xFF131D2E),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                level.icon,
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label + badge
                  Row(
                    children: [
                      Text(
                        level.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          level.badge,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryLight
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    level.tagline,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryLight.withValues(alpha: 0.8)
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    level.description,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Skill bar visualization
                  _SkillBars(
                    filled: level.filledBars,
                    accent: isSelected
                        ? AppColors.primaryLight
                        : AppColors.surfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillBars extends StatelessWidget {
  final int filled;
  final Color accent;
  const _SkillBars({required this.filled, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: isFilled ? accent : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _Level {
  final String label;
  final String tagline;
  final String description;
  final IconData icon;
  final int filledBars;
  final Color accent;
  final List<Color> gradient;
  final String badge;
  const _Level({
    required this.label,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.filledBars,
    required this.accent,
    required this.gradient,
    required this.badge,
  });
}
