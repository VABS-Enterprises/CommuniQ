import 'package:flutter/material.dart';
import 'package:communiq/core/constants/glow.dart';
import 'package:communiq/core/constants/app_colors.dart';

class NeonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBottomGlow;

  const NeonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBottomGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        boxShadow: showBottomGlow
            ? [
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (leading != null)
                leading!
              else
                const SizedBox(width: 48), // Placeholder to center title

              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: AppGlow.mixedGlow(blurRadius: 8, spreadRadius: 0),
                  ),
                ),
              ),

              if (actions != null)
                Row(mainAxisSize: MainAxisSize.min, children: actions!)
              else
                const SizedBox(width: 48), // Placeholder to center title
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

