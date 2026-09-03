import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:communiq/models/visual_analysis_models.dart';

/// Client service that integrates with CommuniQ's AI Server (/evaluate/visual)
/// to fetch LLM-generated coaching insights for visual communication & posture.
class VisualAiCoachingService {
  static const String _aiServerUrl = 'http://10.0.2.2:8000/api/v1/evaluate/visual';

  /// Asynchronously fetches AI LLM-generated coaching insights based on session metrics.
  static Future<List<VisualInsight>> fetchAiInsights({
    required double eyeContactPercentage,
    required double gazeStabilityPercentage,
    required double spineAlignmentPercentage,
    required double shoulderSymmetryPercentage,
    required double chestOpennessPercentage,
    required double headTiltStabilityPercentage,
    required double handMovementPercentage,
    required int overallPostureScore,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_aiServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'eyeContactPercentage': eyeContactPercentage,
              'gazeStabilityPercentage': gazeStabilityPercentage,
              'spineAlignmentPercentage': spineAlignmentPercentage,
              'shoulderSymmetryPercentage': shoulderSymmetryPercentage,
              'chestOpennessPercentage': chestOpennessPercentage,
              'headTiltStabilityPercentage': headTiltStabilityPercentage,
              'handMovementPercentage': handMovementPercentage,
              'overallPostureScore': overallPostureScore,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final insightsList = data['insights'] as List?;
        if (insightsList != null && insightsList.isNotEmpty) {
          return insightsList.map((item) {
            InsightType type = InsightType.suggestion;
            final typeStr = (item['type'] ?? 'suggestion').toString().toLowerCase();
            if (typeStr == 'positive') {
              type = InsightType.positive;
            } else if (typeStr == 'warning') {
              type = InsightType.warning;
            }
            return VisualInsight(
              type: type,
              title: item['title'] ?? 'AI Vision Tip',
              description: item['description'] ?? 'Keep practicing your delivery.',
            );
          }).toList();
        }
      }
    } catch (_) {
      // Fallback seamlessly on timeout or offline mode
    }

    // Dynamic rule-conditioned fallback insights
    return _buildFallbackInsights(
      eyeContactPercentage: eyeContactPercentage,
      spineAlignmentPercentage: spineAlignmentPercentage,
      chestOpennessPercentage: chestOpennessPercentage,
      handMovementPercentage: handMovementPercentage,
    );
  }

  static List<VisualInsight> _buildFallbackInsights({
    required double eyeContactPercentage,
    required double spineAlignmentPercentage,
    required double chestOpennessPercentage,
    required double handMovementPercentage,
  }) {
    final insights = <VisualInsight>[];

    if (eyeContactPercentage >= 70.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Strong Camera Focus',
        description: 'AI Evaluation: You maintained solid camera engagement throughout.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Camera Focus Tip',
        description: 'AI Evaluation: Hold your gaze slightly longer at the camera lens while speaking.',
      ));
    }

    if (spineAlignmentPercentage >= 75.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Upright Spine Alignment',
        description: 'AI Evaluation: Excellent vertical head composure with zero slouching.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Posture Correction',
        description: 'AI Evaluation: Keep your chin level and shoulders square while presenting.',
      ));
    }

    if (handMovementPercentage >= 15.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Expressive Gestures',
        description: 'AI Evaluation: Natural hand movements helped emphasize key points.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Hand Gesture Usage',
        description: 'AI Evaluation: Incorporating open hand movements increases viewer engagement.',
      ));
    }

    return insights;
  }
}
