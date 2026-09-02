import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/models/visual_analysis_models.dart';

/// Renders a percentage progress-bar distribution chart for Head Orientation.
class HeadOrientationChart extends StatelessWidget {
  final Map<HeadOrientation, double> distribution;

  const HeadOrientationChart({
    super.key,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      HeadOrientation.forward,
      HeadOrientation.left,
      HeadOrientation.right,
      HeadOrientation.up,
      HeadOrientation.down,
    ];

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.face_rounded, color: AppColors.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'Head Orientation Distribution',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((orientation) {
            final pct = distribution[orientation] ?? 0.0;
            return _buildBarRow(orientation.label, pct, orientation == HeadOrientation.forward);
          }),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, double percentage, bool isMain) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isMain ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isMain ? AppColors.scoreExcellent : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              color: isMain ? AppColors.secondary : AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
