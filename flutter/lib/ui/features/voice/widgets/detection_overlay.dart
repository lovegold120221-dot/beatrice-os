import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:beatrice/data/services/object_detection_service.dart';

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final ui.Size previewSize;
  final ui.Size viewSize;

  DetectionOverlayPainter({
    required this.objects,
    required this.previewSize,
    required this.viewSize,
  });

  @override
  void paint(Canvas canvas, ui.Size size) {
    if (objects.isEmpty) return;

    final scaleX = viewSize.width / previewSize.width;
    final scaleY = viewSize.height / previewSize.height;

    for (final obj in objects) {
      final rect = Rect.fromLTWH(
        obj.boundingBox.left * scaleX,
        obj.boundingBox.top * scaleY,
        obj.boundingBox.width * scaleX,
        obj.boundingBox.height * scaleY,
      );

      final paint = Paint()
        ..color = Colors.limeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawRect(rect, paint);

      final label = '${obj.label} ${(obj.confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.limeAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          backgroundColor: Color(0x99000000),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelOffset = Offset(rect.left, rect.top - textPainter.height - 2);
      final labelRect = Rect.fromLTWH(
        labelOffset.dx,
        labelOffset.dy,
        textPainter.width + 6,
        textPainter.height + 4,
      );

      canvas.drawRect(labelRect, Paint()..color = const Color(0x99000000));
      textPainter.paint(canvas, labelOffset + const Offset(3, 2));
    }
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) =>
      oldDelegate.objects != objects ||
      oldDelegate.previewSize != previewSize ||
      oldDelegate.viewSize != viewSize;
}
