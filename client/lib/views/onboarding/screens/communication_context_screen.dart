
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/personal_challenges_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class CommunicationContextScreen extends StatefulWidget {
  const CommunicationContextScreen({super.key});

  @override
  State<CommunicationContextScreen> createState() =>
      _CommunicationContextScreenState();
}

class _CommunicationContextScreenState
    extends State<CommunicationContextScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selected = {};
  late AnimationController _entranceCtrl;

  static const _options = [
    _Option('Workplace', Icons.business_center_rounded,
        'Meetings, presentations & everyday team moments'),
    _Option('Job Interviews', Icons.work_rounded,
        'Land the role you deserve — and know you can'),
    _Option('Public Speaking', Icons.record_voice_over_rounded,
        'Own any stage, classroom or spotlight'),
    _Option('Personal Relationships', Icons.favorite_rounded,
        'Say what you mean with the people who matter'),
    _Option('Social Confidence', Icons.people_rounded,
        'Walk into any room and feel at ease'),
    _Option('Sales & Clients', Icons.handshake_rounded,
        'Pitch, negotiate and close with conviction'),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnim(int index) {
    final start = (index / _options.length) * 0.55;
    final end = (start + 0.45).clamp(0.0, 1.0);
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
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 1),

                const SizedBox(height: 28),

                // Title
                const Text(
                  'Where do you want\nto level up?',
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
                  'Select everything that applies to you',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),

                // Card list
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final opt = _options[i];
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
                        child: OnboardingSelectCard(
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
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Selection count hint
                if (_selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Text(
                        '${_selected.length} selected',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                OnboardingButton(
                  label: 'Continue',
                  enabled: _selected.isNotEmpty,
                  onPressed: () {
                    debugPrint(
                        '[Onboarding] Step 1/6 — Contexts: ${_selected.toList()}');
                    Navigator.push(
                      context,
                      slideRoute(PersonalChallengesScreen(
                        data: OnboardingData(contexts: _selected.toList()),
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

class _Option {
  final String label;
  final IconData icon;
  final String subtitle;
  const _Option(this.label, this.icon, this.subtitle);
}
