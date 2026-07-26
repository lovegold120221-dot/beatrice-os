import 'dart:ui' show Rect;
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class DetectedObject {
  final String label;
  final double confidence;
  final Rect boundingBox;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

class ObjectDetectionService {
  ObjectDetector? _detector;

  Future<void> initialize() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _detector = ObjectDetector(options: options);
  }

  Future<List<DetectedObject>> detectImage(String imagePath) async {
    final detector = _detector;
    if (detector == null) return [];
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final results = await detector.processImage(inputImage);
      return results
          .where((o) =>
              o.trackingId == null &&
              o.labels.isNotEmpty &&
              o.labels.any((l) => l.confidence >= 0.5))
          .map((o) {
        final top = o.labels.reduce(
          (a, b) => a.confidence >= b.confidence ? a : b,
        );
        return DetectedObject(
          label: top.text,
          confidence: top.confidence,
          boundingBox: o.boundingBox,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
