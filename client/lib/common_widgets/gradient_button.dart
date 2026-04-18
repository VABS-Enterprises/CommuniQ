import 'package:flutter/material.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/app_colors.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? margin;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.width,
    this.height = 56.0,
    this.margin,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.primaryDark : AppColors.primary,
          borderRadius: AppRadius.buttonRadius,
        ),
        child: Center(
          child: Text(
            widget.text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
