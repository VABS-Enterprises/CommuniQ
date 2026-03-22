import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/onboarding/screens/level_selection_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class SpeakingStyleScreen extends StatefulWidget {
  const SpeakingStyleScreen({super.key});
  @override
  State<SpeakingStyleScreen> createState() => _SpeakingStyleScreenState();
}

class _SpeakingStyleScreenState extends State<SpeakingStyleScreen> {
  String? _selected;
  final TextEditingController _noteController = TextEditingController();

  static const _options = [
    _Option('Calm and quiet', Icons.air_rounded),
    _Option('Fast and energetic', Icons.flash_on_rounded),
    _Option('Confident and direct', Icons.arrow_forward_rounded),
    _Option('Hesitant and unsure', Icons.help_outline_rounded),
    _Option('Friendly and casual', Icons.tag_faces_rounded),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

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
              buildProgressDots(3),
              const SizedBox(height: 28),
              const Text(
                'How do you usually\nspeak?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the closest match',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    ...List.generate(_options.length, (i) {
                      final opt = _options[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OnboardingSelectCard(
                          label: opt.label,
                          icon: opt.icon,
                          isSelected: _selected == opt.label,
                          onTap: () =>
                              setState(() => _selected = opt.label),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    // Optional freeform input
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'Anything specific you want to improve? (optional)',
                          hintStyle: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OnboardingButton(
                label: 'Continue',
                enabled: _selected != null,
                onPressed: () => Navigator.push(
                  context,
                  slideRoute(const LevelSelectionScreen()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final IconData icon;
  const _Option(this.label, this.icon);
}
