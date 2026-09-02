import 'package:communiq/models/visual_analysis_models.dart';

/// Aggregates per-frame vision tracking data into session results.
class VisualAnalysisCalculator {
  /// Aggregates frame results over a session into a complete result document.
  static VisionSessionResult calculateSessionResult({
    required List<VisionFrameResult> frames,
    SessionScenario scenario = SessionScenario.general,
    bool isDemoMode = false,
  }) {
    if (frames.isEmpty) {
      return _buildEmptyResult(scenario: scenario, isDemoMode: isDemoMode);
    }

    final totalFrames = frames.length;
    final totalDuration = frames.last.timestamp.difference(frames.first.timestamp);

    int faceVisibleFrames = 0;
    int eyeContactFrames = 0;
    int headForwardFrames = 0;
    int gazeCenterFrames = 0;
    int activeHandFrames = 0;

    double sumHeadSpine = 0.0;
    double sumShoulderSymmetry = 0.0;
    double sumChestOpenness = 0.0;
    double sumHeadTilt = 0.0;

    final gazeCounts = <GazeDirection, int>{};
    final headCounts = <HeadOrientation, int>{};

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

        sumHeadSpine += frame.headSpineAlignment;
        sumShoulderSymmetry += frame.shoulderSymmetry;
        sumChestOpenness += frame.chestOpenness;
        sumHeadTilt += frame.headTiltStability;
      }

      if (frame.handGestureState == HandGestureState.active) {
        activeHandFrames++;
      }

      gazeCounts[frame.gazeDirection] = (gazeCounts[frame.gazeDirection] ?? 0) + 1;
      headCounts[frame.headOrientation] = (headCounts[frame.headOrientation] ?? 0) + 1;
    }

    final sampleIntervalMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds / totalFrames
        : 100.0;
    final faceVisibleDuration = Duration(milliseconds: (faceVisibleFrames * sampleIntervalMs).round());
    final eyeContactDuration = Duration(milliseconds: (eyeContactFrames * sampleIntervalMs).round());
    final lookingAwayDuration = Duration(milliseconds: ((totalFrames - eyeContactFrames) * sampleIntervalMs).round());

    final faceVisibilityPct = (faceVisibleFrames / totalFrames) * 100.0;
    final eyeContactPct = faceVisibleFrames > 0 ? (eyeContactFrames / faceVisibleFrames) * 100.0 : 0.0;
    final headForwardPct = faceVisibleFrames > 0 ? (headForwardFrames / faceVisibleFrames) * 100.0 : 0.0;
    final gazeStabilityPct = faceVisibleFrames > 0 ? (gazeCenterFrames / faceVisibleFrames) * 100.0 : 0.0;
    final handMovementPct = (activeHandFrames / totalFrames) * 100.0;

    final spineAlignmentPct = faceVisibleFrames > 0 ? (sumHeadSpine / faceVisibleFrames).clamp(0.0, 100.0) : 85.0;
    final shoulderSymmetryPct = faceVisibleFrames > 0 ? (sumShoulderSymmetry / faceVisibleFrames).clamp(0.0, 100.0) : 90.0;
    final chestOpennessPct = faceVisibleFrames > 0 ? (sumChestOpenness / faceVisibleFrames).clamp(0.0, 100.0) : 82.0;
    final headTiltPct = faceVisibleFrames > 0 ? (sumHeadTilt / faceVisibleFrames).clamp(0.0, 100.0) : 92.0;

    final overallPostureScore = ((0.35 * spineAlignmentPct) +
            (0.25 * shoulderSymmetryPct) +
            (0.20 * chestOpennessPct) +
            (0.20 * headTiltPct))
        .clamp(0.0, 100.0)
        .round();

    final gestureScore = (handMovementPct * 1.5).clamp(0.0, 100.0).round();

    final rawScore = (0.40 * eyeContactPct) +
        (0.20 * gazeStabilityPct) +
        (0.25 * overallPostureScore) +
        (0.15 * faceVisibilityPct);
    final engagementScore = rawScore.clamp(0.0, 100.0).round();

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
      spineAlignmentPct: spineAlignmentPct,
      shoulderSymmetryPct: shoulderSymmetryPct,
      chestOpennessPct: chestOpennessPct,
      handMovementPct: handMovementPct,
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
      spineAlignmentPercentage: spineAlignmentPct,
      shoulderSymmetryPercentage: shoulderSymmetryPct,
      chestOpennessPercentage: chestOpennessPct,
      headTiltStabilityPercentage: headTiltPct,
      handMovementPercentage: handMovementPct,
      overallPostureScore: overallPostureScore,
      gestureScore: gestureScore,
      scenario: scenario,
      gazeDistribution: gazeDistribution,
      headOrientationDistribution: headOrientationDistribution,
      visualEngagementScore: engagementScore,
      insights: insights,
      isDemoMode: isDemoMode,
    );
  }

  static List<VisualInsight> _generateInsights({
    required double eyeContactPct,
    required double spineAlignmentPct,
    required double shoulderSymmetryPct,
    required double chestOpennessPct,
    required double handMovementPct,
  }) {
    final insights = <VisualInsight>[];

    // Eye Contact Feedback
    if (eyeContactPct >= 75.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Strong Eye Contact',
        description: 'You maintained solid camera-directed gaze throughout the session.',
      ));
    } else if (eyeContactPct >= 50.0) {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Moderate Eye Contact',
        description: 'Try holding your gaze at the camera for slightly longer while speaking.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.warning,
        title: 'Frequent Disconnection',
        description: 'You looked away frequently. Practice staying focused toward your audience.',
      ));
    }

    // Spine & Head Alignment Feedback
    if (spineAlignmentPct >= 80.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Upright Spine & Head Position',
        description: 'Excellent vertical alignment — your head remained centered over your torso.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Slouching Detected',
        description: 'Forward head posture or slouching was detected. Keep your chin up and spine straight.',
      ));
    }

    // Shoulder Level & Balance Feedback
    if (shoulderSymmetryPct >= 85.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Balanced Shoulder Level',
        description: 'Your shoulders were horizontally level and symmetric throughout.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Uneven Shoulder Dip',
        description: 'Noticeable side-leaning or shoulder dipping detected. Keep weight balanced evenly.',
      ));
    }

    // Chest Openness Feedback
    if (chestOpennessPct >= 75.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Open & Confident Chest Posture',
        description: 'Wide, open shoulder posture communicates high confidence and readiness.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Hunched Shoulder Position',
        description: 'Pull your shoulders back slightly to open up your chest posture.',
      ));
    }

    // Hand Gesture Feedback
    if (handMovementPct >= 15.0) {
      insights.add(const VisualInsight(
        type: InsightType.positive,
        title: 'Expressive Hand Gestures',
        description: 'Active, natural hand movements helped emphasize key points effectively.',
      ));
    } else {
      insights.add(const VisualInsight(
        type: InsightType.suggestion,
        title: 'Hand Gesture Usage',
        description: 'Incorporating natural hand movements while speaking helps engage your listener.',
      ));
    }

    return insights;
  }

  static VisionSessionResult _buildEmptyResult({
    required SessionScenario scenario,
    required bool isDemoMode,
  }) {
    return VisionSessionResult(
      duration: Duration.zero,
      faceVisibleDuration: Duration.zero,
      eyeContactDuration: Duration.zero,
      lookingAwayDuration: Duration.zero,
      eyeContactPercentage: 0.0,
      gazeStabilityPercentage: 0.0,
      headOrientationPercentage: 0.0,
      faceVisibilityPercentage: 0.0,
      spineAlignmentPercentage: 0.0,
      shoulderSymmetryPercentage: 0.0,
      chestOpennessPercentage: 0.0,
      headTiltStabilityPercentage: 0.0,
      handMovementPercentage: 0.0,
      overallPostureScore: 0,
      gestureScore: 0,
      scenario: scenario,
      gazeDistribution: const {},
      headOrientationDistribution: const {},
      visualEngagementScore: 0,
      insights: const [
        VisualInsight(
          type: InsightType.warning,
          title: 'No Data Recorded',
          description: 'No face or posture landmarks were detected during this session.',
        ),
      ],
      isDemoMode: isDemoMode,
    );
  }
}
