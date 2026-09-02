import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/views/visual_analysis/screens/visual_analysis_camera_screen.dart';

/// Home view feature card for launching camera-based visual communication analysis.
class VisualAnalysisCard extends StatelessWidget {
  const VisualAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const VisualAnalysisCameraScreen(),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        glow: true,
        glowColor: AppColors.primary,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: AppColors.primaryLight, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'LIVE CAMERA VISION',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Visual Analysis',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Analyze your camera-based gaze, eye contact & posture in real time.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start Camera Analysis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.secondary.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: AppColors.primaryLight,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
