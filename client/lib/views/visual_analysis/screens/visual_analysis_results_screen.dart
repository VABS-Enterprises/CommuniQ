import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/common_widgets/glass_card.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/models/visual_analysis_models.dart';
import 'package:communiq/core/services/session_service.dart';
import 'package:communiq/views/visual_analysis/screens/visual_analysis_camera_screen.dart';
import 'package:communiq/views/visual_analysis/widgets/gaze_distribution_chart.dart';
import 'package:communiq/views/visual_analysis/widgets/gaze_radar_widget.dart';

/// CommuniQ Visual Communication & Posture Analysis results screen.
class VisualAnalysisResultsScreen extends StatefulWidget {
  final VisionSessionResult sessionResult;

  const VisualAnalysisResultsScreen({
    super.key,
    required this.sessionResult,
  });

  @override
  State<VisualAnalysisResultsScreen> createState() => _VisualAnalysisResultsScreenState();
}

class _VisualAnalysisResultsScreenState extends State<VisualAnalysisResultsScreen> {
  List<VisualInsight>? _aiInsights;
  bool _isLoadingAi = true;

  @override
  void initState() {
    super.initState();
    _aiInsights = widget.sessionResult.insights;
    _fetchAiInsights();
  }

  Future<void> _fetchAiInsights() async {
    final res = widget.sessionResult;
    List<VisualInsight>? aiInsights;

    try {
      // Node server queries Python ai-server Groq LLM model & persists report directly into Firestore!
      aiInsights = await SessionService.instance
          .evaluateAndSaveVisualReport(res)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _aiInsights = (aiInsights != null && aiInsights.isNotEmpty) ? aiInsights : res.insights;
        _isLoadingAi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionResult = widget.sessionResult;

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
            'Visual Analysis Report',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'AI EVALUATED',
                    style: TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
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
                    decoration: BoxDecoration(
                      color: AppColors.sun.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sun.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.sun, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Demo Simulation Mode — Results generated via synthetic vision feed.',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // Hero Engagement Score Ring
                _buildHeroScoreCard(context),
                const SizedBox(height: AppSpacing.s20),

                // Section 1: Eye Contact & Gaze Delivery
                _buildEyeGazeCard(),
                const SizedBox(height: AppSpacing.s20),

                // Section 2: 5 Posture & Computer Vision Body Alignment Metrics
                _buildPostureBreakdownCard(),
                const SizedBox(height: AppSpacing.s20),

                // Section 3: Hand Movement & Gesture Expressiveness
                _buildGestureCard(),
                const SizedBox(height: AppSpacing.s20),

                // Section 4: Categorized CommuniQ AI Insights
                _buildInsightsCard(),
                const SizedBox(height: AppSpacing.s24),

                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisualAnalysisCameraScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text(
                    'Re-Run Camera Analysis',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroScoreCard(BuildContext context) {
    final sessionResult = widget.sessionResult;
    final score = sessionResult.visualEngagementScore;
    Color scoreColor = AppColors.scoreExcellent;
    String ratingLabel = 'EXCELLENT COMMUNICATION';

    if (score < 60) {
      scoreColor = AppColors.scoreNeedsWork;
      ratingLabel = 'NEEDS FOCUS & ALIGNMENT';
    } else if (score < 80) {
      scoreColor = AppColors.scoreNeedsWork;
      ratingLabel = 'GOOD PRESENTATION';
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      glow: true,
      glowColor: scoreColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              ratingLabel,
              style: TextStyle(
                color: scoreColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 12,
                  backgroundColor: AppColors.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Text(
                    'OVERALL SCORE',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatSummary('Eye Contact', '${sessionResult.eyeContactPercentage.round()}%'),
              Container(width: 1, height: 28, color: AppColors.glassBorder),
              _buildStatSummary('Posture Quality', '${sessionResult.overallPostureScore}%'),
              Container(width: 1, height: 28, color: AppColors.glassBorder),
              _buildStatSummary('Gestures', '${sessionResult.gestureScore}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEyeGazeCard() {
    final sessionResult = widget.sessionResult;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.remove_red_eye_rounded, color: AppColors.primaryLight, size: 20),
              SizedBox(width: 8),
              Text(
                'Eye Contact & Gaze Delivery',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Eye Contact',
                  value: '${sessionResult.eyeContactPercentage.round()}%',
                  subtitle: '${sessionResult.eyeContactDuration.inSeconds}s camera focus',
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'Gaze Stability',
                  value: '${sessionResult.gazeStabilityPercentage.round()}%',
                  subtitle: 'Steady center gaze',
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GazeRadarWidget(
            distribution: sessionResult.gazeDistribution,
            eyeContactPct: sessionResult.eyeContactPercentage,
          ),
          const SizedBox(height: 20),
          const Text(
            'Gaze Direction Distribution',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GazeDistributionChart(distribution: sessionResult.gazeDistribution),
        ],
      ),
    );
  }

  Widget _buildPostureBreakdownCard() {
    final sessionResult = widget.sessionResult;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.accessibility_new_rounded, color: AppColors.scoreExcellent, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '5 Vision Posture Metrics',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.scoreExcellent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sessionResult.overallPostureScore}/100',
                  style: const TextStyle(
                    color: AppColors.scoreExcellent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPostureMetricBar(
            title: '1. Spine & Head Vertical Alignment',
            subtitle: 'Detects forward head posture / slouching',
            percentage: sessionResult.spineAlignmentPercentage,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          _buildPostureMetricBar(
            title: '2. Shoulder Level & Symmetry',
            subtitle: 'Detects side-leaning & shoulder dipping',
            percentage: sessionResult.shoulderSymmetryPercentage,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 14),
          _buildPostureMetricBar(
            title: '3. Chest Openness Ratio',
            subtitle: 'Open confident posture vs hunched shoulders',
            percentage: sessionResult.chestOpennessPercentage,
            color: AppColors.scoreExcellent,
          ),
          const SizedBox(height: 14),
          _buildPostureMetricBar(
            title: '4. Head Tilt Stability',
            subtitle: 'Head roll & pitch composure',
            percentage: sessionResult.headTiltStabilityPercentage,
            color: AppColors.sun,
          ),
          const SizedBox(height: 14),
          _buildPostureMetricBar(
            title: '5. Upright Posture Score',
            subtitle: 'Overall upright torso and spine balance',
            percentage: sessionResult.spineAlignmentPercentage,
            color: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildPostureMetricBar({
    required String title,
    required String subtitle,
    required double percentage,
    required Color color,
  }) {
    final pctInt = percentage.round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              '$pctInt%',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pctInt / 100.0,
            minHeight: 8,
            backgroundColor: AppColors.outline,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildGestureCard() {
    final sessionResult = widget.sessionResult;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.back_hand_rounded, color: AppColors.sun, size: 20),
              SizedBox(width: 8),
              Text(
                'Hand Movement & Gestures',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Hand Expressiveness',
                  value: '${sessionResult.handMovementPercentage.round()}%',
                  subtitle: 'Active gesture usage',
                  color: AppColors.sun,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'Gesture Score',
                  value: '${sessionResult.gestureScore}/100',
                  subtitle: 'Dynamic communication',
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    final insights = _aiInsights ?? widget.sessionResult.insights;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CommuniQ AI Insights & Coaching',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isLoadingAi)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) {
            Color cardColor = AppColors.primary;
            IconData icon = Icons.check_circle_outline_rounded;

            if (insight.type == InsightType.positive) {
              cardColor = AppColors.scoreExcellent;
              icon = Icons.stars_rounded;
            } else if (insight.type == InsightType.warning) {
              cardColor = AppColors.scoreNeedsWork;
              icon = Icons.warning_amber_rounded;
            } else {
              cardColor = AppColors.sun;
              icon = Icons.lightbulb_outline_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: cardColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: TextStyle(
                            color: cardColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
