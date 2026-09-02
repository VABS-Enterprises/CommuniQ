import 'package:flutter/material.dart';

/// Classifies estimated gaze direction.
enum GazeDirection {
  center,
  left,
  right,
  up,
  down,
  unknown,
}

extension GazeDirectionExtension on GazeDirection {
  String get label {
    switch (this) {
      case GazeDirection.center:
        return 'CENTER';
      case GazeDirection.left:
        return 'LEFT';
      case GazeDirection.right:
        return 'RIGHT';
      case GazeDirection.up:
        return 'UP';
      case GazeDirection.down:
        return 'DOWN';
      case GazeDirection.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Classifies estimated head orientation.
enum HeadOrientation {
  forward,
  left,
  right,
  up,
  down,
  unknown,
}

extension HeadOrientationExtension on HeadOrientation {
  String get label {
    switch (this) {
      case HeadOrientation.forward:
        return 'FORWARD';
      case HeadOrientation.left:
        return 'LEFT';
      case HeadOrientation.right:
        return 'RIGHT';
      case HeadOrientation.up:
        return 'UP';
      case HeadOrientation.down:
        return 'DOWN';
      case HeadOrientation.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Classifies derived eye contact state.
enum EyeContactState {
  yes,
  no,
  unknown,
}

extension EyeContactStateExtension on EyeContactState {
  String get label {
    switch (this) {
      case EyeContactState.yes:
        return 'YES';
      case EyeContactState.no:
        return 'NO';
      case EyeContactState.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Classifies upper body posture for interviews & presentations.
enum PostureState {
  upright,
  slouched,
  leaningLeft,
  leaningRight,
  unknown,
}

extension PostureStateExtension on PostureState {
  String get label {
    switch (this) {
      case PostureState.upright:
        return 'UPRIGHT';
      case PostureState.slouched:
        return 'SLOUCHED';
      case PostureState.leaningLeft:
        return 'LEANING LEFT';
      case PostureState.leaningRight:
        return 'LEANING RIGHT';
      case PostureState.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Classifies hand movement expressiveness for pitches and presentations.
enum HandGestureState {
  active,
  stationary,
  notVisible,
}

extension HandGestureStateExtension on HandGestureState {
  String get label {
    switch (this) {
      case HandGestureState.active:
        return 'ACTIVE GESTURES';
      case HandGestureState.stationary:
        return 'STATIONARY';
      case HandGestureState.notVisible:
        return 'HANDS OUT OF FRAME';
    }
  }
}

/// Communication scenario context.
enum SessionScenario {
  interview,
  salesPitch,
  general,
}

/// Per-frame vision detection result.
class VisionFrameResult {
  final bool faceDetected;
  final bool multipleFacesDetected;
  final GazeDirection gazeDirection;
  final HeadOrientation headOrientation;
  final EyeContactState eyeContact;
  final PostureState postureState;
  final HandGestureState handGestureState;
  final double headSpineAlignment;
  final double shoulderSymmetry;
  final double chestOpenness;
  final double headTiltStability;
  final double? leftEyeOpenness;
  final double? rightEyeOpenness;
  final Rect? faceBoundingBox;
  final Map<String, Offset>? landmarks;
  final List<Offset>? eyeContours;
  final List<Offset>? shoulderLine;
  final double? rawYaw;
  final double? rawPitch;
  final DateTime timestamp;

  const VisionFrameResult({
    required this.faceDetected,
    this.multipleFacesDetected = false,
    this.gazeDirection = GazeDirection.unknown,
    this.headOrientation = HeadOrientation.unknown,
    this.eyeContact = EyeContactState.unknown,
    this.postureState = PostureState.unknown,
    this.handGestureState = HandGestureState.notVisible,
    this.headSpineAlignment = 84.0,
    this.shoulderSymmetry = 88.0,
    this.chestOpenness = 82.0,
    this.headTiltStability = 90.0,
    this.leftEyeOpenness,
    this.rightEyeOpenness,
    this.faceBoundingBox,
    this.landmarks,
    this.eyeContours,
    this.shoulderLine,
    this.rawYaw,
    this.rawPitch,
    required this.timestamp,
  });

  factory VisionFrameResult.noFace({DateTime? time}) => VisionFrameResult(
        faceDetected: false,
        timestamp: time ?? DateTime.now(),
      );

  factory VisionFrameResult.multipleFaces({DateTime? time}) => VisionFrameResult(
        faceDetected: false,
        multipleFacesDetected: true,
        timestamp: time ?? DateTime.now(),
      );
}

/// Category of constructive communication insight.
enum InsightType {
  positive,
  suggestion,
  warning,
}

/// Individual constructive communication feedback tip.
class VisualInsight {
  final InsightType type;
  final String title;
  final String description;

  const VisualInsight({
    required this.type,
    required this.title,
    required this.description,
  });
}

/// Complete aggregated vision session analysis result.
class VisionSessionResult {
  final Duration duration;
  final Duration faceVisibleDuration;
  final Duration eyeContactDuration;
  final Duration lookingAwayDuration;

  // Eye & Gaze Metrics
  final double eyeContactPercentage;
  final double gazeStabilityPercentage;
  final double headOrientationPercentage;
  final double faceVisibilityPercentage;

  // 5 Detailed Posture & Body Language Metrics
  final double spineAlignmentPercentage;
  final double shoulderSymmetryPercentage;
  final double chestOpennessPercentage;
  final double headTiltStabilityPercentage;
  final double handMovementPercentage;

  final int overallPostureScore;
  final int gestureScore;
  final SessionScenario scenario;
  final Map<GazeDirection, double> gazeDistribution;
  final Map<HeadOrientation, double> headOrientationDistribution;
  final int visualEngagementScore;
  final List<VisualInsight> insights;
  final bool isDemoMode;

  const VisionSessionResult({
    required this.duration,
    required this.faceVisibleDuration,
    required this.eyeContactDuration,
    required this.lookingAwayDuration,
    required this.eyeContactPercentage,
    required this.gazeStabilityPercentage,
    required this.headOrientationPercentage,
    required this.faceVisibilityPercentage,
    required this.spineAlignmentPercentage,
    required this.shoulderSymmetryPercentage,
    required this.chestOpennessPercentage,
    required this.headTiltStabilityPercentage,
    required this.handMovementPercentage,
    required this.overallPostureScore,
    required this.gestureScore,
    this.scenario = SessionScenario.general,
    required this.gazeDistribution,
    required this.headOrientationDistribution,
    required this.visualEngagementScore,
    required this.insights,
    this.isDemoMode = false,
  });
}
