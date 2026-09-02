import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/models/visual_analysis_models.dart';

/// Real-time visual status panel displaying live detection metrics.
class LiveStatusPanel extends StatelessWidget {
  final VisionFrameResult? currentFrame;
  final bool isDemoMode;

  const LiveStatusPanel({
    super.key,
    required this.currentFrame,
    this.isDemoMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final frame = currentFrame;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDemoMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_rounded, color: AppColors.warning, size: 16),
                SizedBox(width: 6),
                Text(
                  'Demo Mode Active',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderAlpha: 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: (frame?.faceDetected ?? false)
                              ? AppColors.emerald
                              : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE ANALYSIS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Gaze, Posture & Gestures',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 12),
              if (frame?.multipleFacesDetected ?? false) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please ensure only one person is visible.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildStatusRow(
                  label: 'Face',
                  value: (frame?.faceDetected ?? false) ? '✓ Detected' : 'Not detected',
                  isPositive: frame?.faceDetected ?? false,
                  color: (frame?.faceDetected ?? false) ? AppColors.emerald : AppColors.textMuted,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  label: 'Gaze',
                  value: frame != null && frame.faceDetected
                      ? frame.gazeDirection.label
                      : 'UNKNOWN',
                  isPositive: frame?.gazeDirection == GazeDirection.center,
                  color: frame?.gazeDirection == GazeDirection.center
                      ? AppColors.emerald
                      : AppColors.primaryLight,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  label: 'Eye Contact',
                  value: frame != null && frame.faceDetected
                      ? (frame.eyeContact == EyeContactState.yes ? '✓ Yes' : 'No')
                      : 'UNKNOWN',
                  isPositive: frame?.eyeContact == EyeContactState.yes,
                  color: frame?.eyeContact == EyeContactState.yes
                      ? AppColors.emerald
                      : AppColors.amber,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  label: 'Posture',
                  value: frame != null && frame.faceDetected
                      ? (frame.postureState == PostureState.upright ? '✓ Upright' : frame.postureState.label)
                      : 'UNKNOWN',
                  isPositive: frame?.postureState == PostureState.upright,
                  color: frame?.postureState == PostureState.upright
                      ? AppColors.emerald
                      : AppColors.amber,
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  label: 'Gestures',
                  value: frame != null && frame.faceDetected
                      ? frame.handGestureState.label
                      : 'UNKNOWN',
                  isPositive: frame?.handGestureState == HandGestureState.active,
                  color: frame?.handGestureState == HandGestureState.active
                      ? AppColors.secondary
                      : AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required bool isPositive,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
