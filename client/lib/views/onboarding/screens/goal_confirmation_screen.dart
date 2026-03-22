import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/main_navigation_view/screens/main_navigation_view.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class GoalConfirmationScreen extends StatefulWidget {
  const GoalConfirmationScreen({super.key});
  @override
  State<GoalConfirmationScreen> createState() =>
      _GoalConfirmationScreenState();
}

class _GoalConfirmationScreenState extends State<GoalConfirmationScreen> {
  String? _selected;

  static const _goals = [
    _Goal('Confidence', Icons.emoji_events_rounded,
        'Speak without hesitation or fear'),
    _Goal('Clarity', Icons.record_voice_over_outlined,
        'Express ideas clearly and concisely'),
    _Goal('Tough Conversations', Icons.shield_outlined,
        'Stay calm and composed under pressure'),
    _Goal('Public Speaking', Icons.mic_external_on_outlined,
        'Captivate any room with your presence'),
    _Goal('Persuasion', Icons.handshake_outlined,
        'Influence and inspire those around you'),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationView()),
      (_) => false,
    );
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
              buildProgressDots(6),
              const SizedBox(height: 28),
              const Text(
                'What do you want\nto improve first?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We'll focus your training here",
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final goal = _goals[i];
                    return OnboardingSelectCard(
                      label: goal.label,
                      icon: goal.icon,
                      subtitle: goal.subtitle,
                      isSelected: _selected == goal.label,
                      onTap: () =>
                          setState(() => _selected = goal.label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // "Final step" indicator
              Center(
                child: Text(
                  '🎉  Final step — you\'re almost in!',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OnboardingButton(
                label: 'Start Training',
                enabled: _selected != null,
                onPressed: _finish,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goal {
  final String label;
  final IconData icon;
  final String subtitle;
  const _Goal(this.label, this.icon, this.subtitle);
}
