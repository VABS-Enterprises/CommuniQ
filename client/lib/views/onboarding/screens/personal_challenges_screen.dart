
import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/validation_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class PersonalChallengesScreen extends StatefulWidget {
  const PersonalChallengesScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<PersonalChallengesScreen> createState() =>
      _PersonalChallengesScreenState();
}

class _PersonalChallengesScreenState extends State<PersonalChallengesScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selected = {};
  late AnimationController _entranceCtrl;

  static const _options = [
    _Option(
      'Feeling nervous',
      Icons.sentiment_dissatisfied_rounded,
      'Heart races, mind goes blank before you even start',
    ),
    _Option(
      'Running out of words',
      Icons.speaker_notes_off_rounded,
      'You know what you want to say — then it vanishes',
    ),
    _Option(
      'Speaking too fast or slow',
      Icons.speed_rounded,
      'Your pace works against you without you realising',
    ),
    _Option(
      'Avoiding difficult talks',
      Icons.shield_rounded,
      'You keep the peace at the cost of being heard',
    ),
    _Option(
      'Ideas get lost in translation',
      Icons.chat_bubble_rounded,
      'What comes out doesn\'t match what you meant',
    ),
    _Option(
      'Lack of confidence',
      Icons.emoji_emotions_rounded,
      'You know what to say — you just can\'t say it boldly',
    ),
    _Option(
      'Being interrupted or talked over',
      Icons.voice_over_off_rounded,
      'Others cut you off and you let them',
    ),
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

                buildOnboardingHeader(context, 2),

                const SizedBox(height: 28),

                const Text(
                  'What holds you\nback the most?',
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
                  "Be honest — we'll tailor your training",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),

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
                        '[Onboarding] Step 2/6 — Challenges: ${_selected.toList()}');
                    Navigator.push(
                      context,
                      slideRoute(ValidationScreen(
                        data: widget.data
                            .copyWith(challenges: _selected.toList()),
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
