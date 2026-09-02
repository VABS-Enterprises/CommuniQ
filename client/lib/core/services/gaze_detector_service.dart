import 'dart:collection';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:communiq/models/visual_analysis_models.dart';

/// Services computer-vision frame analysis using ML Kit Face Detection.
///
/// Converts camera frames into real-time visual communication metrics
/// including face detection, head orientation, approximate gaze direction,
/// and eye contact estimation.
class GazeDetectorService {
  late final FaceDetector _faceDetector;
  bool _isProcessing = false;
  bool _isInitialized = false;

  // Rolling window buffers for temporal smoothing (majority voting)
  final Queue<GazeDirection> _gazeHistory = Queue<GazeDirection>();
  final Queue<HeadOrientation> _headHistory = Queue<HeadOrientation>();
  static const int _kSmoothingWindowSize = 5;

  GazeDetectorService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _isInitialized = true;
  }

  bool get isProcessing => _isProcessing;

  /// Process a single camera image frame.
  /// Drops frame if a previous inference call is still processing.
  Future<VisionFrameResult?> processFrame({
    required CameraImage cameraImage,
    required CameraDescription cameraDescription,
  }) async {
    if (!_isInitialized || _isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(cameraImage, cameraDescription);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      final faces = await _faceDetector.processImage(inputImage);
      final now = DateTime.now();

      if (faces.isEmpty) {
        _clearSmoothingBuffers();
        _isProcessing = false;
        return VisionFrameResult.noFace(time: now);
      }

      if (faces.length > 1) {
        _clearSmoothingBuffers();
        _isProcessing = false;
        return VisionFrameResult.multipleFaces(time: now);
      }

      final face = faces.first;
      final rawResult = _analyzeSingleFace(face, now);
      final smoothedResult = _applyTemporalSmoothing(rawResult);

      _isProcessing = false;
      return smoothedResult;
    } catch (e) {
      debugPrint('[GazeDetectorService] Error processing frame: $e');
      _isProcessing = false;
      return null;
    }
  }

  /// Evaluates single face metrics from ML Kit face landmarks & Euler angles.
  VisionFrameResult _analyzeSingleFace(Face face, DateTime now) {
    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;

    // 1. Head Orientation classification from Euler angles
    HeadOrientation rawHead = HeadOrientation.forward;
    if (yaw < -16.0) {
      rawHead = HeadOrientation.right;
    } else if (yaw > 16.0) {
      rawHead = HeadOrientation.left;
    } else if (pitch < -14.0) {
      rawHead = HeadOrientation.down;
    } else if (pitch > 16.0) {
      rawHead = HeadOrientation.up;
    }

    // 2. Extract available eye landmarks & contours
    final landmarks = <String, Offset>{};
    final leftEyeLandmark = face.landmarks[FaceLandmarkType.leftEye];
    final rightEyeLandmark = face.landmarks[FaceLandmarkType.rightEye];
    final noseLandmark = face.landmarks[FaceLandmarkType.noseBase];

    if (leftEyeLandmark != null) {
      landmarks['leftEye'] = Offset(leftEyeLandmark.position.x.toDouble(), leftEyeLandmark.position.y.toDouble());
    }
    if (rightEyeLandmark != null) {
      landmarks['rightEye'] = Offset(rightEyeLandmark.position.x.toDouble(), rightEyeLandmark.position.y.toDouble());
    }
    if (noseLandmark != null) {
      landmarks['nose'] = Offset(noseLandmark.position.x.toDouble(), noseLandmark.position.y.toDouble());
    }

    final eyeContours = <Offset>[];
    final leftEyeContour = face.contours[FaceContourType.leftEye];
    final rightEyeContour = face.contours[FaceContourType.rightEye];

    if (leftEyeContour != null) {
      for (final pt in leftEyeContour.points) {
        eyeContours.add(Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    }
    if (rightEyeContour != null) {
      for (final pt in rightEyeContour.points) {
        eyeContours.add(Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    }

    // 3. Approximate Gaze Direction using landmarks/contours + head angles
    GazeDirection rawGaze = GazeDirection.center;
    if (rawHead != HeadOrientation.forward) {
      // If head is turned significantly away, gaze tracks head deflection
      switch (rawHead) {
        case HeadOrientation.left:
          rawGaze = GazeDirection.left;
        case HeadOrientation.right:
          rawGaze = GazeDirection.right;
        case HeadOrientation.up:
          rawGaze = GazeDirection.up;
        case HeadOrientation.down:
          rawGaze = GazeDirection.down;
        default:
          rawGaze = GazeDirection.center;
      }
    } else {
      // Head is forward — inspect subtle landmark shifts & eye openness
      if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
        rawGaze = GazeDirection.down; // Eyes mostly closed / looking down
      } else if (landmarks.containsKey('leftEye') && landmarks.containsKey('rightEye') && landmarks.containsKey('nose')) {
        final leftPt = landmarks['leftEye']!;
        final rightPt = landmarks['rightEye']!;
        final nosePt = landmarks['nose']!;

        final eyeMidX = (leftPt.dx + rightPt.dx) / 2.0;
        final noseX = nosePt.dx;
        final horizontalDiff = eyeMidX - noseX;

        // Threshold for relative landmark shift
        if (horizontalDiff > 12.0) {
          rawGaze = GazeDirection.right;
        } else if (horizontalDiff < -12.0) {
          rawGaze = GazeDirection.left;
        } else {
          rawGaze = GazeDirection.center;
        }
      }
    }

    // 4. Derived Eye Contact estimation
    EyeContactState eyeContact = EyeContactState.no;
    final isHeadForward = rawHead == HeadOrientation.forward;
    final isGazeCenter = rawGaze == GazeDirection.center;
    final eyesSufficientlyOpen = leftEyeOpen >= 0.3 && rightEyeOpen >= 0.3;

    if (isHeadForward && isGazeCenter && eyesSufficientlyOpen) {
      eyeContact = EyeContactState.yes;
    } else {
      eyeContact = EyeContactState.no;
    }

    return VisionFrameResult(
      faceDetected: true,
      multipleFacesDetected: false,
      gazeDirection: rawGaze,
      headOrientation: rawHead,
      eyeContact: eyeContact,
      leftEyeOpenness: leftEyeOpen,
      rightEyeOpenness: rightEyeOpen,
      faceBoundingBox: face.boundingBox,
      landmarks: landmarks,
      eyeContours: eyeContours,
      rawYaw: yaw,
      rawPitch: pitch,
      timestamp: now,
    );
  }

  /// Rolling window temporal smoothing to eliminate frame-level jitter.
  VisionFrameResult _applyTemporalSmoothing(VisionFrameResult raw) {
    if (!raw.faceDetected) return raw;

    _gazeHistory.addLast(raw.gazeDirection);
    if (_gazeHistory.length > _kSmoothingWindowSize) {
      _gazeHistory.removeFirst();
    }

    _headHistory.addLast(raw.headOrientation);
    if (_headHistory.length > _kSmoothingWindowSize) {
      _headHistory.removeFirst();
    }

    final smoothedGaze = _majorityVote(_gazeHistory, raw.gazeDirection);
    final smoothedHead = _majorityVote(_headHistory, raw.headOrientation);

    final smoothedEyeContact = (smoothedHead == HeadOrientation.forward &&
            smoothedGaze == GazeDirection.center &&
            (raw.leftEyeOpenness ?? 0.5) >= 0.3 &&
            (raw.rightEyeOpenness ?? 0.5) >= 0.3)
        ? EyeContactState.yes
        : EyeContactState.no;

    return VisionFrameResult(
      faceDetected: true,
      multipleFacesDetected: false,
      gazeDirection: smoothedGaze,
      headOrientation: smoothedHead,
      eyeContact: smoothedEyeContact,
      leftEyeOpenness: raw.leftEyeOpenness,
      rightEyeOpenness: raw.rightEyeOpenness,
      faceBoundingBox: raw.faceBoundingBox,
      landmarks: raw.landmarks,
      eyeContours: raw.eyeContours,
      rawYaw: raw.rawYaw,
      rawPitch: raw.rawPitch,
      timestamp: raw.timestamp,
    );
  }

  T _majorityVote<T>(Queue<T> queue, T fallback) {
    if (queue.isEmpty) return fallback;
    final counts = <T, int>{};
    for (final item in queue) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    T bestItem = fallback;
    int maxCount = 0;
    counts.forEach((item, count) {
      if (count > maxCount) {
        maxCount = count;
        bestItem = item;
      }
    });
    return bestItem;
  }

  void _clearSmoothingBuffers() {
    _gazeHistory.clear();
    _headHistory.clear();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (image.planes.isEmpty) return null;

      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[GazeDetectorService] InputImage build error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
    _clearSmoothingBuffers();
    await _faceDetector.close();
  }
}
