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

/// Per-frame vision detection result.
class VisionFrameResult {
  final bool faceDetected;
  final bool multipleFacesDetected;
  final GazeDirection gazeDirection;
  final HeadOrientation headOrientation;
  final EyeContactState eyeContact;
  final double? leftEyeOpenness;
  final double? rightEyeOpenness;
  final Rect? faceBoundingBox;
  final Map<String, Offset>? landmarks;
  final List<Offset>? eyeContours;
  final double? rawYaw;
  final double? rawPitch;
  final DateTime timestamp;

  const VisionFrameResult({
    required this.faceDetected,
    this.multipleFacesDetected = false,
    this.gazeDirection = GazeDirection.unknown,
    this.headOrientation = HeadOrientation.unknown,
    this.eyeContact = EyeContactState.unknown,
    this.leftEyeOpenness,
    this.rightEyeOpenness,
    this.faceBoundingBox,
    this.landmarks,
    this.eyeContours,
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
  final double eyeContactPercentage;
  final double gazeStabilityPercentage;
  final double headOrientationPercentage;
  final double faceVisibilityPercentage;
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
    required this.gazeDistribution,
    required this.headOrientationDistribution,
    required this.visualEngagementScore,
    required this.insights,
    this.isDemoMode = false,
  });
}
