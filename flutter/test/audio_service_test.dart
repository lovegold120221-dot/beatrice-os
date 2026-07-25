import 'dart:typed_data';

import 'package:beatrice/data/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _constantPcm16(int sample, {int count = 160}) {
  final data = ByteData(count * 2);
  for (var index = 0; index < count; index++) {
    data.setInt16(index * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('PCM microphone meter is silent for zero samples', () {
    expect(AudioService.normalizedPcm16Level(_constantPcm16(0)), 0);
  });

  test('PCM microphone meter rises with actual sample energy', () {
    final quiet = AudioService.normalizedPcm16Level(_constantPcm16(700));
    final speech = AudioService.normalizedPcm16Level(_constantPcm16(6000));
    final loud = AudioService.normalizedPcm16Level(_constantPcm16(25000));

    expect(quiet, greaterThan(0));
    expect(speech, greaterThan(quiet));
    expect(loud, greaterThan(speech));
    expect(loud, lessThanOrEqualTo(1));
  });
}
