import 'package:flutter/material.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';

/// The app's one canonical primary CTA button: primaryGradient fill, a soft
/// primary-colored shadow, AppRadius.buttons corners, scale-on-press. Several
/// screens previously hand-rolled their own version of this (different
/// radius/height/shadow each time) — reach for this instead.
class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? margin;
  final bool enabled;
  final Widget? icon;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.width,
    this.height = 56.0,
    this.margin,
    this.enabled = true,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed!();
            },
      onTapCancel: disabled ? null : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: disabled ? AppColors.textMuted.withValues(alpha: 0.2) : null,
            borderRadius: AppRadius.buttonRadius,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                Text(
                  widget.text,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: disabled ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
