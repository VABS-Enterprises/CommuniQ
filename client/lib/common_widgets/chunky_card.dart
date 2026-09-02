import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/motion.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';
import 'package:communiq/core/constants/spacing.dart';

/// The app's one canonical content card: solid fill, a 2px outline, and a hard
/// offset shadow.
///
/// Pass [onTap] to make it interactive — it then presses like a
/// `ChunkyButton` (translate down, shadow collapses). Without [onTap] it is a
/// static surface and renders a lighter shadow, so tappable and non-tappable
/// cards are visually distinguishable.
///
/// Reach for this instead of hand-rolling `Container` + `BoxDecoration`.
class ChunkyCard extends StatefulWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    this.onTap,
    this.fill,
    this.borderColor,
    this.padding = const EdgeInsets.all(AppSpacing.card),
    this.margin,
    this.borderRadius,
    this.accent,
    this.selected = false,
    this.width,
    this.height,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Surface fill. Defaults to [AppColors.surface].
  final Color? fill;

  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  /// Draws a 6px accent stripe along the card's top edge — used to colour-code
  /// a card by category or status without tinting the whole surface.
  final Color? accent;

  /// Selected cards take the accent (or coral) as their border and a tinted
  /// fill. Used by option grids and scenario pickers.
  final bool selected;

  final double? width;
  final double? height;

  @override
  State<ChunkyCard> createState() => _ChunkyCardState();
}

class _ChunkyCardState extends State<ChunkyCard> {
  bool _held = false;

  bool get _interactive => widget.onTap != null;

  void _setHeld(bool v) {
    if (!_interactive || _held == v) return;
    setState(() => _held = v);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadius.cardRadius;
    final accent = widget.accent ?? AppColors.brand;
    final fill = widget.selected
        ? Color.alphaBlend(accent.withValues(alpha: 0.08), AppColors.surface)
        : (widget.fill ?? AppColors.surface);
    final border = widget.selected
        ? accent
        : (widget.borderColor ?? AppColors.outline);

    final depth = _held ? AppShadow.pressedDepth : AppShadow.restDepth;
    final travel = _interactive ? AppShadow.restDepth - depth : 0.0;

    Widget surface = AnimatedContainer(
      duration: AppMotion.press,
      curve: AppMotion.ease,
      transform: Matrix4.translationValues(0, travel, 0),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(
          color: border,
          width: widget.selected ? 3 : 2,
        ),
        boxShadow: _interactive
            ? AppShadow.hardWith(
                widget.selected ? AppColors.shadowFor(accent) : border,
                y: depth,
              )
            : AppShadow.subtle(),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: widget.accent == null
            ? Padding(padding: widget.padding, child: widget.child)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(height: 6, color: accent),
                  Padding(padding: widget.padding, child: widget.child),
                ],
              ),
      ),
    );

    if (_interactive) {
      surface = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        onTap: widget.onTap,
        child: Semantics(button: true, child: surface),
      );
    }

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: surface,
    );
  }
}
