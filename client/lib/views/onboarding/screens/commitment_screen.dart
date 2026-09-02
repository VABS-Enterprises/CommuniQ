import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/plan_ready_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

/// Commitment device screen — shown after GoalConfirmationScreen.
/// Asking the user to set a weekly practice schedule increases
/// return rate 3x by creating psychological ownership.
class CommitmentScreen extends StatefulWidget {
  const CommitmentScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<CommitmentScreen> createState() => _CommitmentScreenState();
}

class _CommitmentScreenState extends State<CommitmentScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedDays;
  late AnimationController _ctrl;

  static const _options = [
    _Option(
      days: 2,
      label: '2 days / week',
      intensity: 'Relaxed',
      description: 'Build the habit slowly, with zero pressure.',
      icon: Icons.weekend_rounded,
      accentColor: Color(0xFF38BDF8),
    ),
    _Option(
      days: 3,
      label: '3 days / week',
      intensity: 'Balanced',
      description: 'The sweet spot — most users hit their goals here.',
      icon: Icons.local_fire_department_rounded,
      accentColor: Color(0xFF5B52F0),
      isRecommended: true,
    ),
    _Option(
      days: 5,
      label: '5 days / week',
      intensity: 'Intensive',
      description: 'Fast results. High dedication. Real transformation.',
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _anim(double start, double end) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );

  String _motivationalLine() {
    switch (_selectedDays) {
      case 2:
        return 'Consistent beats intense. Good choice.';
      case 3:
        return "3 days is all it took for most of our users to see results.";
      case 5:
        return 'Full commitment. Your results will show it.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 6),

                const SizedBox(height: 32),

                // ── Headline ───────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _anim(0.0, 0.45),
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.2), end: Offset.zero)
                          .animate(_anim(0.0, 0.45)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Now make it stick.',
                        style: TextStyle(
                          color: AppColors.brandLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'How many days\ncan you practise?',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'People who set a schedule are 3× more likely\nto reach their communication goals.',
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Options ────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Column(
                    children: _options.asMap().entries.map((e) {
                      final i = e.key;
                      final opt = e.value;
                      final anim = _anim(0.15 + i * 0.12, 0.60 + i * 0.12);
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                                  begin: const Offset(0, 0.15),
                                  end: Offset.zero)
                              .animate(anim),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OptionCard(
                              option: opt,
                              isSelected: _selectedDays == opt.days,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedDays = opt.days);
                              },
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // ── Motivational line after selection ──────────────────────
                AnimatedOpacity(
                  opacity: _selectedDays != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Center(
                      child: Text(
                        _motivationalLine(),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── CTA ────────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _anim(0.65, 1.0),
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.3), end: Offset.zero)
                          .animate(_anim(0.65, 1.0)),
                      child: child,
                    ),
                  ),
                  child: OnboardingButton(
                    label: 'Lock In My Schedule',
                    enabled: _selectedDays != null,
                    onPressed: () {
                      Navigator.push(
                        context,
                        slideRoute(PlanReadyScreen(
                          data: widget.data
                              .copyWith(commitmentDays: _selectedDays),
                        )),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.inkMuted,
        size: 16,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option Card
// ─────────────────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final _Option option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.brandLight.withValues(alpha: 0.55)
                : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.18)
                    : const Color(0xFF131D2E),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                option.icon,
                color:
                    isSelected ? AppColors.brandLight : AppColors.inkSoft,
                size: 22,
              ),
            ),

            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.ink
                              : AppColors.inkMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (option.isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              color: AppColors.brandLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.intensity,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.brandLight.withValues(alpha: 0.8)
                          : AppColors.inkSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.inkMuted
                          : AppColors.inkSoft,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Check
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.brand : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.outline,
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

class _Option {
  final int days;
  final String label;
  final String intensity;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool isRecommended;
  const _Option({
    required this.days,
    required this.label,
    required this.intensity,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.isRecommended = false,
  });
}
