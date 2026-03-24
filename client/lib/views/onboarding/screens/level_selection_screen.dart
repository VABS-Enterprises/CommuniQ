import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/roleplay_intro_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  String? _selected;

  static const _levels = [
    _Level(
      'Beginner',
      'I feel nervous speaking',
      Icons.sentiment_satisfied_alt_rounded,
    ),
    _Level(
      'Intermediate',
      'I can manage but struggle sometimes',
      Icons.sentiment_neutral_rounded,
    ),
    _Level(
      'Advanced',
      'I want to refine my skills',
      Icons.sentiment_very_satisfied_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              buildProgressDots(4),
              const SizedBox(height: 28),
              const Text(
                'Choose your level',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll adjust difficulty accordingly",
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ...List.generate(_levels.length, (i) {
                final lvl = _levels[i];
                final isSelected = _selected == lvl.label;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = lvl.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              lvl.icon,
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.textMuted,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lvl.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lvl.description,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primaryLight, size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              OnboardingButton(
                label: 'Continue',
                enabled: _selected != null,
                onPressed: () {
                  debugPrint('[Onboarding] Step 4/6 — Level selected: "$_selected"');
                  Navigator.push(
                    context,
                    slideRoute(RoleplayIntroScreen(
                      data: widget.data.copyWith(level: _selected!),
                    )),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Level {
  final String label;
  final String description;
  final IconData icon;
  const _Level(this.label, this.description, this.icon);
}
