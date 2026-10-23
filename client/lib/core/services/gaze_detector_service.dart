import 'dart:collection';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:communiq/models/visual_analysis_models.dart';

/// Services computer-vision frame analysis using ML Kit Face Detection
/// and ML Kit Pose Detection.
///
/// Analyzes real-time visual communication metrics including face detection,
/// head orientation, approximate gaze direction, eye contact, upper-body posture,
/// and hand gesture expressiveness.
class GazeDetectorService {
  late final FaceDetector _faceDetector;
  late final PoseDetector _poseDetector;
  bool _isProcessing = false;
  bool _isInitialized = false;

  // Track previous wrist positions for hand velocity calculation
  Offset? _prevLeftWrist;
  Offset? _prevRightWrist;

  // Rolling window buffers for temporal smoothing (majority voting)
  final Queue<GazeDirection> _gazeHistory = Queue<GazeDirection>();
  final Queue<HeadOrientation> _headHistory = Queue<HeadOrientation>();
  final Queue<PostureState> _postureHistory = Queue<PostureState>();
  final Queue<HandGestureState> _gestureHistory = Queue<HandGestureState>();
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
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
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

      final facesFuture = _faceDetector.processImage(inputImage);
      final posesFuture = _poseDetector.processImage(inputImage);

      final faces = await facesFuture;
      final poses = await posesFuture;
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
      final pose = poses.isNotEmpty ? poses.first : null;

      final rawResult = _analyzeFaceAndPose(face, pose, now);
      final smoothedResult = _applyTemporalSmoothing(rawResult);

      _isProcessing = false;
      return smoothedResult;
    } catch (e) {
      debugPrint('[GazeDetectorService] Error processing frame: $e');
      _isProcessing = false;
      return null;
    }
  }

  /// Evaluates face, posture, and hand gesture metrics from ML Kit outputs.
  VisionFrameResult _analyzeFaceAndPose(Face face, Pose? pose, DateTime now) {
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
      if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
        rawGaze = GazeDirection.down;
      } else if (landmarks.containsKey('leftEye') && landmarks.containsKey('rightEye') && landmarks.containsKey('nose')) {
        final leftPt = landmarks['leftEye']!;
        final rightPt = landmarks['rightEye']!;
        final nosePt = landmarks['nose']!;

        final eyeMidX = (leftPt.dx + rightPt.dx) / 2.0;
        final noseX = nosePt.dx;
        final horizontalDiff = eyeMidX - noseX;

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

    // 5 Posture & Body Language Computer Vision Metrics
    PostureState postureState = PostureState.upright;
    HandGestureState handGestureState = HandGestureState.notVisible;
    List<Offset>? shoulderLine;

    // Dynamic computer vision posture metrics computed from Face & Pose landmarks
    final headRoll = (face.headEulerAngleZ ?? 0.0).abs();
    final headYawAbs = (face.headEulerAngleY ?? 0.0).abs();
    final headPitchVal = (face.headEulerAngleX ?? 0.0);

    // 1. Head & Spine Vertical Alignment (Slouching / Forward Head)
    double headSpineAlignment = (88.0 + (headPitchVal * 1.8)).clamp(35.0, 98.0);

    // 2. Shoulder Level & Symmetry
    double shoulderSymmetry = (95.0 - (headYawAbs * 1.2) - (headRoll * 1.4)).clamp(40.0, 98.0);

    // 3. Chest Openness Ratio
    final faceBox = face.boundingBox;
    final faceRatio = faceBox.height > 0 ? (faceBox.width / faceBox.height) : 0.8;
    double chestOpenness = (faceRatio * 105.0).clamp(45.0, 96.0);

    // 4. Head Tilt Stability
    double headTiltStability = (98.0 - (headRoll * 3.2)).clamp(30.0, 98.0);

    if (pose != null) {
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

      if (leftShoulder != null && rightShoulder != null && leftShoulder.likelihood > 0.4 && rightShoulder.likelihood > 0.4) {
        final ls = Offset(leftShoulder.x, leftShoulder.y);
        final rs = Offset(rightShoulder.x, rightShoulder.y);
        shoulderLine = [ls, rs];

        final shoulderDiffY = (rs.dy - ls.dy).abs();
        shoulderSymmetry = (100.0 - (shoulderDiffY * 2.8)).clamp(25.0, 98.0);

        final shoulderWidth = (rs.dx - ls.dx).abs();
        if (faceBox.width > 0) {
          final ratio = shoulderWidth / faceBox.width;
          chestOpenness = (ratio * 52.0).clamp(40.0, 98.0);
        }

        final shoulderMidY = (ls.dy + rs.dy) / 2.0;
        final faceBoxTop = faceBox.top;
        final headShoulderDistance = shoulderMidY - faceBoxTop;
        if (faceBox.height > 0) {
          final vertRatio = headShoulderDistance / faceBox.height;
          headSpineAlignment = (vertRatio * 58.0).clamp(30.0, 98.0);
        }

        // Posture State Classification
        if (shoulderDiffY > 28.0) {
          postureState = rs.dy > ls.dy ? PostureState.leaningRight : PostureState.leaningLeft;
        } else if (pitch < -12.0 || headSpineAlignment < 60.0) {
          postureState = PostureState.slouched;
        } else {
          postureState = PostureState.upright;
        }
      } else if (pitch < -12.0) {
        postureState = PostureState.slouched;
      }

      // Hand Gesture Evaluation
      bool hasWristVisible = false;
      double maxHandVelocity = 0.0;

      if (leftWrist != null && leftWrist.likelihood > 0.5) {
        hasWristVisible = true;
        final lw = Offset(leftWrist.x, leftWrist.y);
        if (_prevLeftWrist != null) {
          maxHandVelocity = (lw - _prevLeftWrist!).distance;
        }
        _prevLeftWrist = lw;
      }

      if (rightWrist != null && rightWrist.likelihood > 0.5) {
        hasWristVisible = true;
        final rw = Offset(rightWrist.x, rightWrist.y);
        if (_prevRightWrist != null) {
          final dist = (rw - _prevRightWrist!).distance;
          if (dist > maxHandVelocity) maxHandVelocity = dist;
        }
        _prevRightWrist = rw;
      }

      if (hasWristVisible) {
        if (maxHandVelocity > 8.0) {
          handGestureState = HandGestureState.active;
        } else {
          handGestureState = HandGestureState.stationary;
        }
      } else {
        handGestureState = HandGestureState.notVisible;
      }
    }

    return VisionFrameResult(
      faceDetected: true,
      multipleFacesDetected: false,
      gazeDirection: rawGaze,
      headOrientation: rawHead,
      eyeContact: eyeContact,
      postureState: postureState,
      handGestureState: handGestureState,
      headSpineAlignment: headSpineAlignment,
      shoulderSymmetry: shoulderSymmetry,
      chestOpenness: chestOpenness,
      headTiltStability: headTiltStability,
      leftEyeOpenness: leftEyeOpen,
      rightEyeOpenness: rightEyeOpen,
      faceBoundingBox: face.boundingBox,
      landmarks: landmarks,
      eyeContours: eyeContours,
      shoulderLine: shoulderLine,
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

    _postureHistory.addLast(raw.postureState);
    if (_postureHistory.length > _kSmoothingWindowSize) {
      _postureHistory.removeFirst();
    }

    _gestureHistory.addLast(raw.handGestureState);
    if (_gestureHistory.length > _kSmoothingWindowSize) {
      _gestureHistory.removeFirst();
    }

    final smoothedGaze = _majorityVote(_gazeHistory, raw.gazeDirection);
    final smoothedHead = _majorityVote(_headHistory, raw.headOrientation);
    final smoothedPosture = _majorityVote(_postureHistory, raw.postureState);
    final smoothedGesture = _majorityVote(_gestureHistory, raw.handGestureState);

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
      postureState: smoothedPosture,
      handGestureState: smoothedGesture,
      leftEyeOpenness: raw.leftEyeOpenness,
      rightEyeOpenness: raw.rightEyeOpenness,
      faceBoundingBox: raw.faceBoundingBox,
      landmarks: raw.landmarks,
      eyeContours: raw.eyeContours,
      shoulderLine: raw.shoulderLine,
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
    _postureHistory.clear();
    _gestureHistory.clear();
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    try {
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;

      if (image.planes.isEmpty) return null;

      // ML Kit's fromByteArray only accepts NV21 or YV12; handed anything else
      // it throws IllegalArgumentException and every frame is dropped. The
      // camera is opened with ImageFormatGroup.nv21, but the plugin still
      // reports the ImageReader's YUV_420_888 as image.format.raw, so trusting
      // that value meant declaring an unsupported format on every frame.
      //
      // A single plane is already NV21. Three planes are planar YUV that has to
      // be packed into NV21 (full Y, then interleaved V/U) before ML Kit can
      // read it.
      //
      // iOS keeps its own path: there the camera delivers bgra8888, which ML
      // Kit accepts as reported.
      if (defaultTargetPlatform != TargetPlatform.android) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);
        if (format == null) return null;
        return InputImage.fromBytes(
          bytes: image.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes.first.bytesPerRow,
          ),
        );
      }

      final repacked = image.planes.length > 1;
      final bytes =
          repacked ? _yuv420ToNv21(image) : image.planes.first.bytes;
      if (bytes == null) return null;

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          // Repacking removes the plane padding, so the stride is now the
          // image width rather than the original padded row length.
          bytesPerRow: repacked ? image.width : image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[GazeDetectorService] InputImage build error: $e');
      return null;
    }
  }

  /// Packs a 3-plane YUV_420_888 frame into a single NV21 buffer: the whole Y
  /// plane followed by V and U interleaved. Row and pixel strides are honoured
  /// because planes are commonly padded to an alignment wider than the image.
  Uint8List? _yuv420ToNv21(CameraImage image) {
    if (image.planes.length < 3) return null;

    final width = image.width;
    final height = image.height;
    final out = Uint8List(width * height + 2 * ((width + 1) ~/ 2) * ((height + 1) ~/ 2));

    final yPlane = image.planes[0];
    var offset = 0;
    for (var row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      out.setRange(offset, offset + width, yPlane.bytes, start);
      offset += width;
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvHeight = (height + 1) ~/ 2;
    final uvWidth = (width + 1) ~/ 2;

    for (var row = 0; row < uvHeight; row++) {
      for (var col = 0; col < uvWidth; col++) {
        final index = row * uvRowStride + col * uvPixelStride;
        if (index >= vPlane.bytes.length || index >= uPlane.bytes.length) {
          return null;
        }
        out[offset++] = vPlane.bytes[index];
        out[offset++] = uPlane.bytes[index];
      }
    }

    return out;
  }

  Future<void> dispose() async {
    _isInitialized = false;
    _clearSmoothingBuffers();
    await _faceDetector.close();
    await _poseDetector.close();
  }
}
