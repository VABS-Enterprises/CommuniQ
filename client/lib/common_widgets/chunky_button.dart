import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/app_text_styles.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';

enum ChunkyButtonVariant { primary, secondary, success, ghost, danger }

enum ChunkyButtonSize { sm, md, lg }

/// The app's one canonical button.
///
/// Its defining behaviour is the press: the surface **translates down** by
/// exactly the amount its hard shadow shrinks, so the button appears to
/// physically depress into the page rather than fade or ripple. Everything
/// else — colour, size, loading, icons — is configuration around that.
///
/// Reach for this instead of `ElevatedButton` or a hand-rolled
/// `Container` + `BoxDecoration`; screens previously rolled their own version
/// with a different radius/height/shadow each time.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ChunkyButtonVariant.primary,
    this.size = ChunkyButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
    this.margin,
  });

  final String label;

  /// `null` disables the button (as with Material's buttons).
  final VoidCallback? onPressed;

  final ChunkyButtonVariant variant;
  final ChunkyButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Fill the available width. Set false for an intrinsic-width button.
  final bool expand;

  /// Shows a spinner and blocks taps. The button keeps its width so a row
  /// doesn't reflow when an action starts.
  final bool loading;

  final EdgeInsetsGeometry? margin;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _held = false;

  bool get _disabled =>
      widget.onPressed == null || widget.loading;

  ({Color fill, Color content, Color? border}) get _palette {
    if (_disabled) {
      return (
        fill: AppColors.bgSunk,
        content: AppColors.inkSoft,
        border: null,
      );
    }
    return switch (widget.variant) {
      ChunkyButtonVariant.primary => (
          fill: AppColors.coral,
          content: AppColors.inkOnDark,
          border: null,
        ),
      ChunkyButtonVariant.secondary => (
          fill: AppColors.surface,
          content: AppColors.ink,
          border: AppColors.outline,
        ),
      ChunkyButtonVariant.success => (
          fill: AppColors.success,
          content: AppColors.inkOnDark,
          border: null,
        ),
      ChunkyButtonVariant.danger => (
          fill: AppColors.error,
          content: AppColors.inkOnDark,
          border: null,
        ),
      ChunkyButtonVariant.ghost => (
          fill: AppColors.transparent,
          content: AppColors.inkMuted,
          border: null,
        ),
    };
  }

  double get _height => switch (widget.size) {
        ChunkyButtonSize.sm => 40,
        ChunkyButtonSize.md => 52,
        ChunkyButtonSize.lg => 60,
      };

  TextStyle get _labelStyle => switch (widget.size) {
        ChunkyButtonSize.sm => AppTextStyles.labelMedium,
        ChunkyButtonSize.md => AppTextStyles.labelLarge,
        ChunkyButtonSize.lg => AppTextStyles.labelLarge.copyWith(fontSize: 17),
      };

  double get _iconSize => switch (widget.size) {
        ChunkyButtonSize.sm => 16,
        ChunkyButtonSize.md => 20,
        ChunkyButtonSize.lg => 22,
      };

  void _setHeld(bool v) {
    if (_disabled || _held == v) return;
    setState(() => _held = v);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final isGhost = widget.variant == ChunkyButtonVariant.ghost;

    // A ghost button is flat by definition — no slab, no travel.
    final depth = isGhost
        ? 0.0
        : _held
            ? AppShadow.pressedDepth
            : AppShadow.restDepth;
    final travel = isGhost ? 0.0 : AppShadow.restDepth - depth;

    final content = widget.loading
        ? SizedBox(
            height: _iconSize,
            width: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(palette.content),
            ),
          )
        : Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: _iconSize, color: palette.content),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _labelStyle.copyWith(color: palette.content),
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(widget.trailingIcon,
                    size: _iconSize, color: palette.content),
              ],
            ],
          );

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: Semantics(
        button: true,
        enabled: !_disabled,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setHeld(true),
          onTapUp: (_) => _setHeld(false),
          onTapCancel: () => _setHeld(false),
          onTap: _disabled ? null : widget.onPressed,
          // Reserve the full travel + depth so the button never shifts the
          // layout of whatever sits below it as it animates.
          child: SizedBox(
            height: _height + AppShadow.restDepth,
            width: widget.expand ? double.infinity : null,
            child: AnimatedContainer(
              duration: AppMotion.press,
              curve: AppMotion.ease,
              transform: Matrix4.translationValues(0, travel, 0),
              height: _height,
              decoration: BoxDecoration(
                color: palette.fill,
                borderRadius: AppRadius.buttonRadius,
                border: palette.border == null
                    ? null
                    : Border.all(color: palette.border!, width: 2),
                boxShadow: depth == 0
                    ? null
                    : AppShadow.hard(palette.fill, y: depth),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.size == ChunkyButtonSize.sm ? 14 : 20,
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
