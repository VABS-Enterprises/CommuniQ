import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/visual_analysis_models.dart';

/// Renders camera visual landmark overlays, face bounding box,
/// eye landmark/contour visualization, and gaze-direction indicator.
class CameraLandmarkPainter extends CustomPainter {
  final VisionFrameResult? frameResult;
  final Size previewSize;
  final bool isFrontCamera;

  CameraLandmarkPainter({
    required this.frameResult,
    required this.previewSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frameResult == null || !frameResult!.faceDetected) return;

    final scaleX = size.width / (previewSize.width > 0 ? previewSize.width : size.width);
    final scaleY = size.height / (previewSize.height > 0 ? previewSize.height : size.height);

    // 1. Draw Face Bounding Box
    if (frameResult!.faceBoundingBox != null) {
      final box = frameResult!.faceBoundingBox!;
      double left = box.left * scaleX;
      double right = box.right * scaleX;
      final top = box.top * scaleY;
      final bottom = box.bottom * scaleY;

      // Handle front camera mirror mapping
      if (isFrontCamera) {
        final temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final boxPaint = Paint()
        ..color = frameResult!.eyeContact == EyeContactState.yes
            ? AppColors.scoreExcellent.withValues(alpha: 0.7)
            : AppColors.primaryLight.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final cornerLength = 20.0;
      final cornerPaint = Paint()
        ..color = frameResult!.eyeContact == EyeContactState.yes
            ? AppColors.scoreExcellent
            : AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      // Draw rounded main rect
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        boxPaint,
      );

      // Draw tech corners
      // Top-Left
      canvas.drawLine(Offset(rect.left, rect.top + cornerLength), Offset(rect.left, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);

      // Top-Right
      canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right, rect.top), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), cornerPaint);

      // Bottom-Left
      canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);

      // Bottom-Right
      canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
      canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);
    }

    // 2. Eye Contour Visualization
    if (frameResult!.eyeContours != null && frameResult!.eyeContours!.isNotEmpty) {
      final pointPaint = Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.fill;

      for (final rawPt in frameResult!.eyeContours!) {
        double px = rawPt.dx * scaleX;
        double py = rawPt.dy * scaleY;
        if (isFrontCamera) px = size.width - px;

        canvas.drawCircle(Offset(px, py), 1.8, pointPaint);
      }
    }

    // 3. Eye Landmarks & Gaze Direction Indicator
    if (frameResult!.landmarks != null) {
      final landmarkPaint = Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.fill;

      frameResult!.landmarks!.forEach((name, rawPt) {
        double lx = rawPt.dx * scaleX;
        double ly = rawPt.dy * scaleY;
        if (isFrontCamera) lx = size.width - lx;

        final pt = Offset(lx, ly);
        canvas.drawCircle(pt, 3.5, landmarkPaint);

        // Draw gaze-direction reticle for eye landmarks
        if (name == 'leftEye' || name == 'rightEye') {
          _drawGazeDirectionIndicator(canvas, pt, frameResult!.gazeDirection);
        }
      });
    }
  }

  void _drawGazeDirectionIndicator(Canvas canvas, Offset eyeCenter, GazeDirection direction) {
    double dx = 0.0;
    double dy = 0.0;

    switch (direction) {
      case GazeDirection.center:
        break;
      case GazeDirection.left:
        dx = isFrontCamera ? 16.0 : -16.0;
        break;
      case GazeDirection.right:
        dx = isFrontCamera ? -16.0 : 16.0;
        break;
      case GazeDirection.up:
        dy = -16.0;
        break;
      case GazeDirection.down:
        dy = 16.0;
        break;
      case GazeDirection.unknown:
        return;
    }

    final target = eyeCenter + Offset(dx, dy);

    final linePaint = Paint()
      ..color = direction == GazeDirection.center ? AppColors.scoreExcellent : AppColors.warning
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = direction == GazeDirection.center ? AppColors.scoreExcellent : AppColors.warning
      ..style = PaintingStyle.fill;

    if (direction != GazeDirection.center) {
      canvas.drawLine(eyeCenter, target, linePaint);
      canvas.drawCircle(target, 4.0, dotPaint);
    } else {
      // Subtle target ring for CENTER gaze
      canvas.drawCircle(eyeCenter, 7.0, linePaint..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant CameraLandmarkPainter oldDelegate) {
    return oldDelegate.frameResult != frameResult;
  }
}
