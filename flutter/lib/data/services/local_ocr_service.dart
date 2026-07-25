import 'package:flutter/services.dart';

class LocalOcrResult {
  final String text;
  final int confidence;
  final String language;
  final String engine;

  const LocalOcrResult({
    required this.text,
    required this.confidence,
    required this.language,
    required this.engine,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'meanConfidence': confidence,
    'language': language,
    'engine': engine,
  };
}

class LocalOcrService {
  static const _channel = MethodChannel('com.eburon.beatrice/local_ocr_v1');

  Future<bool> isEnglishReady() async {
    final status = await _channel.invokeMapMethod<String, dynamic>('status');
    return status?['englishReady'] == true;
  }

  Future<bool> importEnglishData() async {
    return await _channel.invokeMethod<bool>('selectEnglishData') ?? false;
  }

  Future<({Uint8List bytes, String name})?> pickImageDocument() async {
    final value = await _channel.invokeMapMethod<String, dynamic>(
      'selectImageDocument',
    );
    if (value == null) return null;
    final bytes = value['bytes'];
    if (bytes is! Uint8List) {
      throw const FormatException('The selected image could not be read.');
    }
    return (bytes: bytes, name: value['name']?.toString() ?? 'document');
  }

  Future<void> removeEnglishData() async {
    await _channel.invokeMethod<void>('removeEnglish');
  }

  Future<LocalOcrResult> recognize(Uint8List image) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(
      'recognizeEnglish',
      {'image': image},
    );
    if (value == null) throw PlatformException(code: 'OCR_FAILED');
    return LocalOcrResult(
      text: value['text']?.toString() ?? '',
      confidence: value['confidence'] as int? ?? 0,
      language: value['language']?.toString() ?? 'eng',
      engine: value['engine']?.toString() ?? 'Tesseract',
    );
  }
}
