import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/core/constants/spacing.dart';
import 'package:communiq/common_widgets/sky_campus_background.dart';
import 'package:communiq/core/services/gaze_detector_service.dart';
import 'package:communiq/core/services/visual_analysis_calculator.dart';
import 'package:communiq/models/visual_analysis_models.dart';
import 'package:communiq/views/visual_analysis/screens/visual_analysis_results_screen.dart';
import 'package:communiq/views/visual_analysis/widgets/camera_landmark_painter.dart';
import 'package:communiq/views/visual_analysis/widgets/live_status_panel.dart';

/// Camera-based live eye tracking and visual communication analysis screen.
class VisualAnalysisCameraScreen extends StatefulWidget {
  const VisualAnalysisCameraScreen({super.key});

  @override
  State<VisualAnalysisCameraScreen> createState() => _VisualAnalysisCameraScreenState();
}

class _VisualAnalysisCameraScreenState extends State<VisualAnalysisCameraScreen> {
  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  late final GazeDetectorService _gazeService;

  bool _isInitializingCamera = true;
  bool _cameraPermissionDenied = false;
  String? _cameraErrorMessage;

  final SessionScenario _currentScenario = SessionScenario.interview;

  bool _isDemoMode = false;
  Timer? _demoTimer;
  final Random _random = Random();

  bool _isAnalyzing = false;
  Timer? _sessionTimer;
  Duration _elapsedDuration = Duration.zero;

  VisionFrameResult? _latestFrame;
  final List<VisionFrameResult> _recordedFrames = [];

  @override
  void initState() {
    super.initState();
    _gazeService = GazeDetectorService();
    _initCameraPipeline();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _demoTimer?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _gazeService.dispose();
    super.dispose();
  }

  /// Initialize front camera and ML Kit stream.
  Future<void> _initCameraPipeline() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraPermissionDenied = false;
      _cameraErrorMessage = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _cameraPermissionDenied = true;
          _isInitializingCamera = false;
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception('No camera available'),
      );

      _frontCamera = front;
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isInitializingCamera = false;
      });

      // Start frame listener
      await controller.startImageStream((CameraImage image) {
        if (!mounted || _isDemoMode || _frontCamera == null) return;
        _onCameraFrameAvailable(image);
      });
    } catch (e) {
      debugPrint('[VisualAnalysisScreen] Camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'Camera unavailable or unsupported on this device.';
          _isInitializingCamera = false;
        });
      }
    }
  }

  /// Handle incoming camera frames from image stream.
  Future<void> _onCameraFrameAvailable(CameraImage image) async {
    if (_gazeService.isProcessing || _frontCamera == null) return;

    final frameResult = await _gazeService.processFrame(
      cameraImage: image,
      cameraDescription: _frontCamera!,
    );

    if (frameResult != null && mounted) {
      setState(() => _latestFrame = frameResult);
      if (_isAnalyzing) {
        _recordedFrames.add(frameResult);
      }
    }
  }

  /// Toggles session analysis start / stop.
  void _toggleAnalysis() {
    if (_isAnalyzing) {
      _stopAnalysisAndShowResults();
    } else {
      _startAnalysis();
    }
  }

  void _startAnalysis() {
    setState(() {
      _isAnalyzing = true;
      _elapsedDuration = Duration.zero;
      _recordedFrames.clear();
    });

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedDuration += const Duration(seconds: 1));
      }
    });

    if (_isDemoMode) {
      _startDemoFrameGenerator();
    }
  }

  void _stopAnalysisAndShowResults() {
    _sessionTimer?.cancel();
    _demoTimer?.cancel();

    setState(() => _isAnalyzing = false);

    // Compute session result
    final result = VisualAnalysisCalculator.calculateSessionResult(
      frames: _recordedFrames,
      scenario: _currentScenario,
      isDemoMode: _isDemoMode,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisualAnalysisResultsScreen(sessionResult: result),
      ),
    );
  }

  /// Fallback demo frame simulator for environments without live camera feeds.
  void _enableDemoMode() {
    _cameraController?.stopImageStream().catchError((_) {});

    setState(() {
      _isDemoMode = true;
      _cameraPermissionDenied = false;
      _cameraErrorMessage = null;
      _isInitializingCamera = false;
    });

    _startDemoFrameGenerator();
  }

  void _startDemoFrameGenerator() {
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;

      final p = _random.nextDouble();
      GazeDirection gaze = GazeDirection.center;
      HeadOrientation head = HeadOrientation.forward;
      EyeContactState eyeContact = EyeContactState.yes;
      PostureState posture = PostureState.upright;
      HandGestureState gesture = HandGestureState.active;

      if (p < 0.70) {
        gaze = GazeDirection.center;
        head = HeadOrientation.forward;
        eyeContact = EyeContactState.yes;
        posture = PostureState.upright;
        gesture = HandGestureState.active;
      } else if (p < 0.82) {
        gaze = GazeDirection.left;
        head = HeadOrientation.left;
        eyeContact = EyeContactState.no;
        posture = PostureState.slouched;
        gesture = HandGestureState.stationary;
      } else if (p < 0.92) {
        gaze = GazeDirection.right;
        head = HeadOrientation.right;
        eyeContact = EyeContactState.no;
        posture = PostureState.upright;
        gesture = HandGestureState.active;
      } else {
        gaze = GazeDirection.down;
        head = HeadOrientation.down;
        eyeContact = EyeContactState.no;
        posture = PostureState.slouched;
        gesture = HandGestureState.notVisible;
      }

      double spineVal = 84.0 + (_random.nextDouble() * 10.0 - 5.0);
      double shoulderVal = 88.0 + (_random.nextDouble() * 8.0 - 4.0);
      double chestVal = 82.0 + (_random.nextDouble() * 10.0 - 5.0);
      double tiltVal = 90.0 + (_random.nextDouble() * 8.0 - 4.0);

      if (posture == PostureState.slouched) {
        spineVal = 58.0 + (_random.nextDouble() * 10.0);
        shoulderVal = 70.0 + (_random.nextDouble() * 8.0);
        chestVal = 62.0 + (_random.nextDouble() * 10.0);
        tiltVal = 72.0 + (_random.nextDouble() * 8.0);
      }

      final demoFrame = VisionFrameResult(
        faceDetected: true,
        gazeDirection: gaze,
        headOrientation: head,
        eyeContact: eyeContact,
        postureState: posture,
        handGestureState: gesture,
        headSpineAlignment: spineVal,
        shoulderSymmetry: shoulderVal,
        chestOpenness: chestVal,
        headTiltStability: tiltVal,
        leftEyeOpenness: 0.9,
        rightEyeOpenness: 0.9,
        timestamp: DateTime.now(),
      );

      setState(() => _latestFrame = demoFrame);

      if (_isAnalyzing) {
        _recordedFrames.add(demoFrame);
      }
    });
  }

  String _formatTimer(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

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
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CommuniQ Visual Analysis',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Gaze, Posture & Hand Gestures',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            if (!_isDemoMode) ...[
              IconButton(
                tooltip: 'Switch to Demo Mode',
                icon: const Icon(Icons.science_rounded, color: AppColors.primaryLight),
                onPressed: _enableDemoMode,
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildCameraContainer(),
                      if (_isAnalyzing)
                        Positioned(
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgVoid.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTimer(_elapsedDuration),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: LiveStatusPanel(
                  currentFrame: _latestFrame,
                  isDemoMode: _isDemoMode,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _toggleAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAnalyzing ? AppColors.error : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAnalyzing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAnalyzing ? 'Stop Analysis' : 'Start Analysis',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraContainer() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitializingCamera)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
            else if (_cameraPermissionDenied)
              _buildFallbackCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera Access Required',
                subtitle: 'Camera permission is needed for live eye contact, posture, and gesture analysis.',
                actionText: 'Use Demo Mode',
                onAction: _enableDemoMode,
              )
            else if (_cameraErrorMessage != null)
              _buildFallbackCard(
                icon: Icons.videocam_off_outlined,
                title: 'Camera Unavailable',
                subtitle: _cameraErrorMessage!,
                actionText: 'Run in Demo Mode',
                onAction: _enableDemoMode,
              )
            else if (_isDemoMode)
              Container(
                color: AppColors.bgDark,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.face_rounded, size: 80, color: AppColors.primaryLight),
                      const SizedBox(height: 16),
                      const Text(
                        'Demo Mode Simulation',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Simulating real-time front camera vision feed',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _initCameraPipeline,
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryLight),
                        label: const Text('Try Real Camera', style: TextStyle(color: AppColors.primaryLight)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_cameraController != null && _cameraController!.value.isInitialized)
              LayoutBuilder(
                builder: (context, constraints) {
                  final rawSize = _cameraController!.value.previewSize!;
                  final double imgW = min(rawSize.width, rawSize.height);
                  final double imgH = max(rawSize.width, rawSize.height);

                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: imgW,
                      height: imgH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_cameraController!),
                          CustomPaint(
                            painter: CameraLandmarkPainter(
                              frameResult: _latestFrame,
                              previewSize: Size(imgW, imgH),
                              isFrontCamera: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
