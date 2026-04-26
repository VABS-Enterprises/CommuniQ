
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/onboarding_data.dart';
import 'package:communiq/views/onboarding/screens/level_selection_screen.dart';
import 'package:communiq/views/onboarding/widgets/onboarding_utils.dart';

class SpeakingStyleScreen extends StatefulWidget {
  const SpeakingStyleScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<SpeakingStyleScreen> createState() => _SpeakingStyleScreenState();
}

class _SpeakingStyleScreenState extends State<SpeakingStyleScreen>
    with SingleTickerProviderStateMixin {
  String? _selected;
  final TextEditingController _noteController = TextEditingController();
  late AnimationController _entranceCtrl;
  bool _noteFocused = false;

  static const _styles = [
    _Style(
      label: 'Calm & Quiet',
      tagline: 'You choose words carefully, speak softly',
      icon: Icons.air_rounded,
      accent: Color(0xFF38BDF8),   // sky blue
      gradient: [Color(0xFF0C2233), Color(0xFF0D1525)],
    ),
    _Style(
      label: 'Fast & Energetic',
      tagline: 'Your mind races and the words keep up',
      icon: Icons.bolt_rounded,
      accent: Color(0xFFF59E0B),   // amber
      gradient: [Color(0xFF231A0C), Color(0xFF0D1525)],
    ),
    _Style(
      label: 'Confident & Direct',
      tagline: 'You say what you mean, no filler words',
      icon: Icons.arrow_forward_rounded,
      accent: Color(0xFF5B52F0),   // indigo
      gradient: [Color(0xFF130D2E), Color(0xFF0D1525)],
    ),
    _Style(
      label: 'Hesitant & Unsure',
      tagline: 'You second-guess yourself before speaking',
      icon: Icons.help_outline_rounded,
      accent: Color(0xFFA78BFA),   // violet
      gradient: [Color(0xFF1A0D2E), Color(0xFF0D1525)],
    ),
    _Style(
      label: 'Friendly & Casual',
      tagline: 'Easy-going, warm and approachable tone',
      icon: Icons.tag_faces_rounded,
      accent: Color(0xFF10B981),   // emerald
      gradient: [Color(0xFF0C2218), Color(0xFF0D1525)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnim(int index) {
    final start = (index / _styles.length) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                buildOnboardingHeader(context, 3),

                const SizedBox(height: 28),

                const Text(
                  'How do you naturally\nspeak?',
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
                  'Pick the closest match — be honest!',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ...List.generate(_styles.length, (i) {
                        final style = _styles[i];
                        final anim = _itemAnim(i);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AnimatedBuilder(
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
                            child: _StyleCard(
                              style: style,
                              isSelected: _selected == style.label,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selected = style.label);
                              },
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 4),

                      // Optional note field
                      Focus(
                        onFocusChange: (f) =>
                            setState(() => _noteFocused = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _noteFocused
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : AppColors.cardBorder,
                              width: _noteFocused ? 1.5 : 1,
                            ),
                          ),
                          child: TextField(
                            controller: _noteController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.55,
                            ),
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
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                OnboardingButton(
                  label: 'Continue',
                  enabled: _selected != null,
                  onPressed: () {
                    final note = _noteController.text.trim();
                    debugPrint(
                        '[Onboarding] Step 3/6 — Style: "$_selected"'
                        '${note.isNotEmpty ? ', note: "$note"' : ''}');
                    Navigator.push(
                      context,
                      slideRoute(LevelSelectionScreen(
                        data: widget.data.copyWith(
                          speakingStyle: _selected!,
                          speakingNote: note.isEmpty ? null : note,
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Style Card — custom because each has a unique accent colour
// ─────────────────────────────────────────────────────────────────────────────

class _StyleCard extends StatelessWidget {
  final _Style style;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryLight.withValues(alpha: 0.55)
                : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : const Color(0xFF131D2E),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                style.icon,
                color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    style.tagline,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Check
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
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

class _Style {
  final String label;
  final String tagline;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;
  const _Style({
    required this.label,
    required this.tagline,
    required this.icon,
    required this.accent,
    required this.gradient,
  });
}
