import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/onboarding/screens/speaking_style_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class PersonalChallengesScreen extends StatefulWidget {
  const PersonalChallengesScreen({super.key});
  @override
  State<PersonalChallengesScreen> createState() =>
      _PersonalChallengesScreenState();
}

class _PersonalChallengesScreenState extends State<PersonalChallengesScreen> {
  final Set<String> _selected = {};

  static const _options = [
    _Option('Feeling nervous', Icons.sentiment_dissatisfied_outlined),
    _Option('Running out of words', Icons.speaker_notes_off_outlined),
    _Option('Speaking too fast or too slow', Icons.speed_outlined),
    _Option('Avoiding difficult conversations', Icons.shield_outlined),
    _Option('Not expressing clearly', Icons.chat_bubble_outline_rounded),
    _Option('Lack of confidence', Icons.emoji_emotions_outlined),
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
              buildProgressDots(2),
              const SizedBox(height: 28),
              const Text(
                'What do you struggle\nwith most?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll personalise your training",
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final opt = _options[i];
                    return OnboardingSelectCard(
                      label: opt.label,
                      icon: opt.icon,
                      isSelected: _selected.contains(opt.label),
                      onTap: () => setState(() {
                        if (_selected.contains(opt.label)) {
                          _selected.remove(opt.label);
                        } else {
                          _selected.add(opt.label);
                        }
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              OnboardingButton(
                label: 'Continue',
                enabled: _selected.isNotEmpty,
                onPressed: () => Navigator.push(
                  context,
                  slideRoute(const SpeakingStyleScreen()),
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
