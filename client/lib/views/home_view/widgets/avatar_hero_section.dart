import 'package:flutter/material.dart';

import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/core/constants/app_colors.dart';

class AvatarHeroSection extends StatefulWidget {
  /// Optional URL of the user's profile photo (e.g. from Google sign-in).
  /// Falls back to the hummingbird asset when null.
  final String? photoURL;

  const AvatarHeroSection({super.key, this.photoURL});

  @override
  State<AvatarHeroSection> createState() => _AvatarHeroSectionState();
}

class _AvatarHeroSectionState extends State<AvatarHeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: AppGlow.mixedGlow(blurRadius: 30, spreadRadius: 5),
          ),
          child: Center(
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
              ),
              child: ClipOval(
                child: widget.photoURL != null
                    ? Image.network(
                        widget.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultImage(),
                      )
                    : _defaultImage(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultImage() {
    return Image.asset(
      'assets/images/hummingbird.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.person, size: 80, color: AppColors.white),
    );
  }
}
