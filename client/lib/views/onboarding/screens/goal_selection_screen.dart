import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/views/main_navigation_view/screens/main_navigation_view.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  final Set<String> _selected = {};

  final List<_GoalOption> _goals = const [
    _GoalOption(
      value: 'Speak with Confidence',
      icon: Icons.emoji_events_rounded,
      description: 'Build the courage to express yourself clearly',
    ),
    _GoalOption(
      value: 'Improve Conversations',
      icon: Icons.chat_bubble_outline_rounded,
      description: 'Be more natural in everyday interactions',
    ),
    _GoalOption(
      value: 'Handle Difficult Situations',
      icon: Icons.shield_outlined,
      description: 'Stay calm and effective under pressure',
    ),
    _GoalOption(
      value: 'Become a Leader',
      icon: Icons.people_alt_outlined,
      description: 'Inspire and influence teams around you',
    ),
    _GoalOption(
      value: 'Ace Interviews',
      icon: Icons.work_outline_rounded,
      description: 'Present your best self in any interview',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s24),
              _buildProgressDots(3),
              const SizedBox(height: AppSpacing.s32),
              const Text(
                'What do you want\nto improve?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Select all that apply',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.s24),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s10),
                  itemBuilder: (_, i) => _buildGoalCard(_goals[i]),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('onboarding_complete', true);
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainNavigationView(),
                            ),
                            (_) => false,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.surface,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(_GoalOption goal) {
    final isSelected = _selected.contains(goal.value);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selected.remove(goal.value);
        } else {
          _selected.add(goal.value);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.s14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                goal.icon,
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.value,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.description,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalOption {
  final String value;
  final IconData icon;
  final String description;
  const _GoalOption(
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
          color: i == activeIndex ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}
