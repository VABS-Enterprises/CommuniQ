import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/radius.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Progress Bar
// step: 1–6, total: 6
// ─────────────────────────────────────────────────────────────────────────────

Widget buildProgressBar(int step, {int total = 6}) {
  return Row(
    children: List.generate(total, (i) {
      final filled = i < step;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          height: 3,
          margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: filled ? AppColors.brand : AppColors.surfaceAlt,
          ),
        ),
      );
    }),
  );
}

// Legacy alias so existing call-sites (buildProgressDots) keep compiling.
// Maps the old 7-dot activeIndex to the new 6-bar step.
Widget buildProgressDots(int activeIndex, {int total = 7}) =>
    buildProgressBar(activeIndex, total: total - 1);

// ─────────────────────────────────────────────────────────────────────────────
// Page Transition
// ─────────────────────────────────────────────────────────────────────────────

Route slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      final fade = Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(
              parent: anim, curve: const Interval(0.0, 0.5)));
      return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
    },
    transitionDuration: const Duration(milliseconds: 380),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient Background – used on all inner onboarding screens
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingBackground extends StatelessWidget {
  final Widget child;
  const OnboardingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base fill
        const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
        // Top-left ambient orb
        Positioned(
          top: -80,
          left: -80,
          child: _GlowOrb(
            size: 280,
            color: AppColors.brand.withValues(alpha: 0.10),
          ),
        ),
        // Bottom-right violet orb
        Positioned(
          bottom: -60,
          right: -60,
          child: _GlowOrb(
            size: 220,
            color: AppColors.brand.withValues(alpha: 0.07),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selectable Card  (used across every onboarding selection screen)
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingSelectCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const OnboardingSelectCard({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.brandLight.withValues(alpha: 0.55)
                : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brand.withValues(alpha: 0.18)
                      : AppColors.bgSunk,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.brandLight
                      : AppColors.inkSoft,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.ink
                          : AppColors.inkMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.inkMuted
                            : AppColors.inkSoft,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.brand : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.outline,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.inkOnDark, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Button — full-width gradient with glow + press scale
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool showGradient;
  final VoidCallback? onPressed;

  const OnboardingButton({
    super.key,
    required this.label,
    this.enabled = true,
    this.showGradient = false,
    this.onPressed,
  });

  @override
  State<OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<OnboardingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.mediumImpact();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [AppColors.brand, AppColors.brandLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: widget.enabled ? null : AppColors.surfaceAlt,
            borderRadius: AppRadius.buttonRadius,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.enabled ? AppColors.inkOnDark : AppColors.inkSoft,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Header — back button + progress bar + step label
// ─────────────────────────────────────────────────────────────────────────────

Widget buildOnboardingHeader(BuildContext context, int step, {int total = 6}) {
  return Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
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
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: buildProgressBar(step, total: total)),
      const SizedBox(width: 12),
      buildStepLabel(step, total: total),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step label chip – "STEP 1 OF 6" badge
// ─────────────────────────────────────────────────────────────────────────────

Widget buildStepLabel(int step, {int total = 6}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.brand.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.brand.withValues(alpha: 0.25),
        width: 1,
      ),
    ),
    child: Text(
      'STEP $step OF $total',
      style: const TextStyle(
        color: AppColors.brandLight,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}
