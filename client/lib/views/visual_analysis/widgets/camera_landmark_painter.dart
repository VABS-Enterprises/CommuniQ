import 'package:flutter/material.dart';
import 'package:communiq/core/constants/app_colors.dart';
import 'package:communiq/models/visual_analysis_models.dart';

/// Renders a clean, perfectly aligned face bounding box overlay.
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
    if (frameResult == null || !frameResult!.faceDetected || frameResult!.faceBoundingBox == null) return;

    final box = frameResult!.faceBoundingBox!;

    final double scaleX = size.width / (previewSize.width > 0 ? previewSize.width : size.width);
    final double scaleY = size.height / (previewSize.height > 0 ? previewSize.height : size.height);

    double left = box.left * scaleX;
    double right = box.right * scaleX;
    final top = box.top * scaleY;
    final bottom = box.bottom * scaleY;

    // Handle front camera horizontal mirror mapping
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

    const cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = frameResult!.eyeContact == EyeContactState.yes
          ? AppColors.scoreExcellent
          : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Draw main rounded face bounding box
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      boxPaint,
    );

    // Draw tech corner brackets
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

  @override
  bool shouldRepaint(covariant CameraLandmarkPainter oldDelegate) {
    return oldDelegate.frameResult != frameResult;
  }
}
