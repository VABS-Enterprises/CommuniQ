import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/views/onboarding/screens/first_roleplay_screen.dart';

class SkillLevelScreen extends StatefulWidget {
  const SkillLevelScreen({super.key});

  @override
  State<SkillLevelScreen> createState() => _SkillLevelScreenState();
}

class _SkillLevelScreenState extends State<SkillLevelScreen> {
  String? _selected;

  final List<_SkillOption> _options = const [
    _SkillOption(
      value: 'Beginner',
      icon: Icons.sentiment_satisfied_alt_rounded,
      description: 'I get nervous easily or avoid conversations',
    ),
    _SkillOption(
      value: 'Intermediate',
      icon: Icons.sentiment_neutral_rounded,
      description: 'I can hold conversations but struggle in tough ones',
    ),
    _SkillOption(
      value: 'Advanced',
      icon: Icons.sentiment_very_satisfied_rounded,
      description: 'I communicate well but want to level up further',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s24),
              _buildProgressDots(1),
              const SizedBox(height: AppSpacing.s32),
              const Text(
                'How comfortable are\nyou in conversations?',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Be honest — we personalise your path',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.s32),
              ...List.generate(
                _options.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: _buildOptionCard(_options[i]),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.push(
                            context,
                            _slideRoute(const FirstRoleplayScreen()),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    disabledBackgroundColor: AppColors.surface,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Continue',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(_SkillOption option) {
    final isSelected = _selected == option.value;
    return GestureDetector(
      onTap: () => setState(() => _selected = option.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.15)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                color: isSelected ? AppColors.brandLight : AppColors.inkSoft,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.value,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.inkMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.brandLight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SkillOption {
  final String value;
  final IconData icon;
  final String description;
  const _SkillOption(
      {required this.value, required this.icon, required this.description});
}

Widget _buildProgressDots(int activeIndex) {
  return Row(
    children: List.generate(
      4,
      (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 6),
        width: i == activeIndex ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == activeIndex ? AppColors.brand : AppColors.outline,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

Route _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}
