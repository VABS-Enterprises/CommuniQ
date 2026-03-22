import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/views/onboarding/screens/personal_challenges_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class CommunicationContextScreen extends StatefulWidget {
  const CommunicationContextScreen({super.key});
  @override
  State<CommunicationContextScreen> createState() =>
      _CommunicationContextScreenState();
}

class _CommunicationContextScreenState
    extends State<CommunicationContextScreen> {
  final Set<String> _selected = {};

  static const _options = [
    _Option('Workplace', Icons.business_center_outlined,
        'Meetings, presentations, colleagues'),
    _Option('Interviews', Icons.work_outline_rounded,
        'Job and scholarship interviews'),
    _Option('Public Speaking', Icons.record_voice_over_outlined,
        'Stages, classrooms, events'),
    _Option('Relationships', Icons.favorite_border_rounded,
        'Partners, family, close friends'),
    _Option('Friends / Social', Icons.people_outline_rounded,
        'Social settings and networking'),
    _Option('Sales / Clients', Icons.handshake_outlined,
        'Pitches, negotiations, clients'),
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
              buildProgressDots(1),
              const SizedBox(height: 28),
              const Text(
                'Where do you want\nto improve?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select all that apply',
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
                      subtitle: opt.subtitle,
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
                  slideRoute(const PersonalChallengesScreen()),
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
  final String subtitle;
  const _Option(this.label, this.icon, this.subtitle);
}
