import 'package:flutter/material.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/radius.dart';
import 'package:communiq/core/constants/shadows.dart';

/// An icon in a rounded, colour-filled square. The app's standard way to give
/// a list row or card header a piece of colour.
///
/// [tinted] (the default) uses a soft background with a saturated icon, which
/// sits calmly inside a card. Set it false for a solid fill with a white icon
/// and a hard shadow, for when the tile is the focal point.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.size = 44,
    this.tinted = true,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final bool tinted;

  /// The soft companion for each brand colour, used as the tinted background.
  static Color _soft(Color c) {
    if (c == AppColors.coral) return AppColors.coralSoft;
    if (c == AppColors.sun) return AppColors.sunSoft;
    if (c == AppColors.teal) return AppColors.tealSoft;
    if (c == AppColors.grape) return AppColors.grapeSoft;
    if (c == AppColors.success) return AppColors.successSoft;
    if (c == AppColors.error) return AppColors.errorSoft;
    if (c == AppColors.info) return AppColors.infoSoft;
    return Color.alphaBlend(c.withValues(alpha: 0.14), AppColors.surface);
  }

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.coral;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tinted ? _soft(tint) : tint,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: tinted ? null : AppShadow.hard(tint, y: 3),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: tinted ? tint : AppColors.inkOnDark,
      ),
    );
  }
}

/// A small count/status badge (pill with a label) — unread markers, rank numbers, "NEW" flags.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.inkOnDark),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: AppColors.inkOnDark,
            ),
          ),
        ],
      ),
    );
  }
}
