import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/models/visual_analysis_models.dart';
import 'package:communiq/views/visual_analysis/screens/visual_analysis_camera_screen.dart';
import 'package:communiq/views/visual_analysis/widgets/gaze_distribution_chart.dart';
import 'package:communiq/views/visual_analysis/widgets/head_orientation_chart.dart';

/// CommuniQ Visual Communication Analysis results screen.
class VisualAnalysisResultsScreen extends StatelessWidget {
  final VisionSessionResult sessionResult;

  const VisualAnalysisResultsScreen({
    super.key,
    required this.sessionResult,
  });

  @override
  Widget build(BuildContext context) {
    return SkyCampusBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Visual Analysis Results',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sessionResult.isDemoMode) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Results generated from Demo Simulation Mode',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildHeroScoreCard(context),
                const SizedBox(height: 20),
                _buildIndividualMetricsGrid(),
                const SizedBox(height: 24),
                GazeDistributionChart(distribution: sessionResult.gazeDistribution),
                const SizedBox(height: 20),
                HeadOrientationChart(distribution: sessionResult.headOrientationDistribution),
                const SizedBox(height: 24),
                _buildInsightsSection(),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.glassBorder),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Back to Home',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VisualAnalysisCameraScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroScoreCard(BuildContext context) {
    final score = sessionResult.visualEngagementScore;
    String feedback = 'Good Visual Engagement';
    Color scoreColor = AppColors.scoreExcellent;

    if (score < 50) {
      feedback = 'Needs Practice';
      scoreColor = AppColors.scoreNeedsWork;
    } else if (score < 75) {
      feedback = 'Moderate Engagement';
      scoreColor = AppColors.secondary;
    }

    return GlassCard(
      padding: const EdgeInsets.all(28),
      glow: true,
      glowColor: scoreColor,
      child: Column(
        children: [
          const Text(
            'VISUAL ENGAGEMENT',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 10,
                  backgroundColor: AppColors.surfaceVariant,
                  color: scoreColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'Score',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              feedback,
              style: TextStyle(
                color: scoreColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analysis Duration: ${sessionResult.duration.inSeconds} seconds',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.remove_red_eye_rounded,
                iconColor: AppColors.primaryLight,
                label: 'Eye Contact',
                percentage: sessionResult.eyeContactPercentage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.center_focus_strong_rounded,
                iconColor: AppColors.secondary,
                label: 'Gaze Stability',
                percentage: sessionResult.gazeStabilityPercentage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.face_rounded,
                iconColor: AppColors.emerald,
                label: 'Head Orientation',
                percentage: sessionResult.headOrientationPercentage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.visibility_rounded,
                iconColor: AppColors.gold,
                label: 'Face Visibility',
                percentage: sessionResult.faceVisibilityPercentage,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double percentage,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${percentage.round()}%',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                'CommuniQ Insights',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sessionResult.insights.map(_buildInsightItem),
        ],
      ),
    );
  }

  Widget _buildInsightItem(VisualInsight insight) {
    Color badgeColor;
    IconData iconData;

    switch (insight.type) {
      case InsightType.positive:
        badgeColor = AppColors.emerald;
        iconData = Icons.check_circle_outline_rounded;
        break;
      case InsightType.suggestion:
        badgeColor = AppColors.secondary;
        iconData = Icons.arrow_forward_rounded;
        break;
      case InsightType.warning:
        badgeColor = AppColors.amber;
        iconData = Icons.warning_amber_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: badgeColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
