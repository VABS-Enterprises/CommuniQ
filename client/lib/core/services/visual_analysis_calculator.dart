import 'package:communiq/models/visual_analysis_models.dart';

/// Aggregates per-frame computer vision measurements into a complete session result.
class VisualAnalysisCalculator {
  /// Computes final session analysis metrics from captured frame samples.
  ///
  /// Note on Visual Engagement Score:
  /// The formula used is a prototype heuristic metric designed for real-time practice feedback:
  ///   Score = (0.50 * EyeContact%) + (0.20 * GazeStability%) + (0.20 * HeadForward%) + (0.10 * FaceVisibility%)
  ///
  /// This is an exploratory communication heuristic and is NOT a scientifically
  /// validated psychological or attention score.
  static VisionSessionResult calculateSessionResult({
    required List<VisionFrameResult> frames,
    required Duration totalDuration,
    bool isDemoMode = false,
  }) {
    if (frames.isEmpty || totalDuration.inMilliseconds == 0) {
      return _emptyResult(totalDuration, isDemoMode);
    }

    final totalFrames = frames.length;
    int faceVisibleFrames = 0;
    int eyeContactFrames = 0;
    int headForwardFrames = 0;
    int gazeCenterFrames = 0;

    final gazeCounts = <GazeDirection, int>{
      GazeDirection.center: 0,
      GazeDirection.left: 0,
      GazeDirection.right: 0,
      GazeDirection.up: 0,
      GazeDirection.down: 0,
      GazeDirection.unknown: 0,
    };

    final headCounts = <HeadOrientation, int>{
      HeadOrientation.forward: 0,
      HeadOrientation.left: 0,
      HeadOrientation.right: 0,
      HeadOrientation.up: 0,
      HeadOrientation.down: 0,
      HeadOrientation.unknown: 0,
    };

    for (final frame in frames) {
      if (frame.faceDetected) {
        faceVisibleFrames++;
        if (frame.eyeContact == EyeContactState.yes) {
          eyeContactFrames++;
        }
        if (frame.headOrientation == HeadOrientation.forward) {
          headForwardFrames++;
        }
        if (frame.gazeDirection == GazeDirection.center) {
          gazeCenterFrames++;
        }
      }

      gazeCounts[frame.gazeDirection] = (gazeCounts[frame.gazeDirection] ?? 0) + 1;
      headCounts[frame.headOrientation] = (headCounts[frame.headOrientation] ?? 0) + 1;
    }

    final sampleIntervalMs = totalDuration.inMilliseconds / totalFrames;
    final faceVisibleDuration = Duration(milliseconds: (faceVisibleFrames * sampleIntervalMs).round());
    final eyeContactDuration = Duration(milliseconds: (eyeContactFrames * sampleIntervalMs).round());
    final lookingAwayDuration = Duration(milliseconds: ((totalFrames - eyeContactFrames) * sampleIntervalMs).round());

    final faceVisibilityPct = (faceVisibleFrames / totalFrames) * 100.0;
    final eyeContactPct = faceVisibleFrames > 0 ? (eyeContactFrames / faceVisibleFrames) * 100.0 : 0.0;
    final headForwardPct = faceVisibleFrames > 0 ? (headForwardFrames / faceVisibleFrames) * 100.0 : 0.0;
    final gazeStabilityPct = faceVisibleFrames > 0 ? (gazeCenterFrames / faceVisibleFrames) * 100.0 : 0.0;

    // Prototype heuristic metric formula
    final rawScore = (0.50 * eyeContactPct) +
        (0.20 * gazeStabilityPct) +
        (0.20 * headForwardPct) +
        (0.10 * faceVisibilityPct);
    final engagementScore = rawScore.clamp(0.0, 100.0).round();

    // Compute distribution percentages
    final gazeDistribution = <GazeDirection, double>{};
    gazeCounts.forEach((direction, count) {
      gazeDistribution[direction] = (count / totalFrames) * 100.0;
    });

    final headOrientationDistribution = <HeadOrientation, double>{};
    headCounts.forEach((orientation, count) {
      headOrientationDistribution[orientation] = (count / totalFrames) * 100.0;
    });

    final insights = _generateInsights(
      eyeContactPct: eyeContactPct,
      headForwardPct: headForwardPct,
      faceVisibilityPct: faceVisibilityPct,
      gazeStabilityPct: gazeStabilityPct,
    );

    return VisionSessionResult(
      duration: totalDuration,
      faceVisibleDuration: faceVisibleDuration,
      eyeContactDuration: eyeContactDuration,
      lookingAwayDuration: lookingAwayDuration,
      eyeContactPercentage: eyeContactPct,
      gazeStabilityPercentage: gazeStabilityPct,
      headOrientationPercentage: headForwardPct,
      faceVisibilityPercentage: faceVisibilityPct,
      gazeDistribution: gazeDistribution,
      headOrientationDistribution: headOrientationDistribution,
      visualEngagementScore: engagementScore,
      insights: insights,
      isDemoMode: isDemoMode,
    );
  }

  static List<VisualInsight> _generateInsights({
    required double eyeContactPct,
    required double headForwardPct,
    required double faceVisibilityPct,
    required double gazeStabilityPct,
  }) {
    final insights = <VisualInsight>[];

    // Eye Contact Feedback
    if (eyeContactPct >= 75.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Excellent Eye Contact',
        description: 'You maintained strong camera-directed gaze throughout the exercise.',
      ));
    } else if (eyeContactPct >= 50.0) {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Moderate Eye Contact',
        description: 'Try maintaining camera-directed gaze for slightly longer periods while speaking.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.warning,
        title: 'Frequent Disconnection',
        description: 'You looked away frequently during the exercise. Practice focusing toward your audience.',
      ));
    }

    // Head Orientation Feedback
    if (headForwardPct >= 80.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Centered Posture',
        description: 'Your head orientation remained steadily facing forward.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Head Orientation',
        description: 'Keep your face turned toward the camera to maintain a direct visual connection.',
      ));
    }

    // Face Visibility / Lighting Feedback
    if (faceVisibilityPct < 85.0) {
      insights.add(const VisualInsight(
        type: InsightType.warning,
        title: 'Visibility Adjustments',
        description: 'Try positioning yourself in well-lit space so your face remains clearly visible.',
      ));
    }

    return insights;
  }

  static VisionSessionResult _emptyResult(Duration duration, bool isDemoMode) {
    return VisionSessionResult(
      duration: duration,
      faceVisibleDuration: Duration.zero,
      eyeContactDuration: Duration.zero,
      lookingAwayDuration: duration,
      eyeContactPercentage: 0,
      gazeStabilityPercentage: 0,
      headOrientationPercentage: 0,
      faceVisibilityPercentage: 0,
      gazeDistribution: {
        GazeDirection.center: 0,
        GazeDirection.left: 0,
        GazeDirection.right: 0,
        GazeDirection.up: 0,
        GazeDirection.down: 0,
        GazeDirection.unknown: 100,
      },
      headOrientationDistribution: {
        HeadOrientation.forward: 0,
        HeadOrientation.left: 0,
        HeadOrientation.right: 0,
        HeadOrientation.up: 0,
        HeadOrientation.down: 0,
        HeadOrientation.unknown: 100,
      },
      visualEngagementScore: 0,
      insights: [
        const VisualInsight(
          type: InsightType.warning,
          title: 'No Face Detected',
          description: 'Ensure your face is clearly visible in the camera frame before starting.',
        ),
      ],
      isDemoMode: isDemoMode,
    );
  }
}
