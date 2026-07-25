import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class AudioService {
  static const _livePcm = MethodChannel('com.eburon.beatrice/live_pcm_v1');
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;

  bool _isRecording = false;
  final bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Converts little-endian mono PCM16 microphone samples to a perceptual
  /// 0–1 level suitable for a realtime input meter.
  static double normalizedPcm16Level(Uint8List pcmData) {
    final sampleCount = pcmData.length ~/ 2;
    if (sampleCount == 0) return 0;
    final samples = ByteData.sublistView(pcmData);
    var sumSquares = 0.0;
    for (var index = 0; index < sampleCount; index++) {
      final sample = samples.getInt16(index * 2, Endian.little) / 32768.0;
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms <= 0.000001) return 0;
    final decibels = 20 * (math.log(rms) / math.ln10);
    return ((decibels + 60) / 54).clamp(0.0, 1.0);
  }

  Future<Stream<Uint8List>?> startPcmStream({int sampleRate = 16000}) async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission denied');
    }
    _isRecording = true;
    // record 7.x: startStream returns a Stream<Uint8List> synchronously.
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: sampleRate,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: 1280,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
          audioManagerMode: AudioManagerMode.modeInCommunication,
          speakerphone: true,
        ),
      ),
    );
    return stream;
  }

  Future<void> stopStream() async {
    _isRecording = false;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/beatrice_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
  }

  Future<String?> stopRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_recordingPath == null) return null;
    final file = File(_recordingPath!);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    await file.delete();
    _recordingPath = null;
    return base64Encode(bytes);
  }

  Future<void> playPcmAudio(Uint8List pcmData, int sampleRate) async {
    final wav = _pcmToWav(pcmData, sampleRate);
    await _player.play(BytesSource(wav));
  }

  Future<void> playBase64Audio(String base64Data) async {
    final bytes = base64Decode(base64Data);
    await _player.play(BytesSource(bytes));
  }

  Future<void> playFile(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    try {
      await _livePcm.invokeMethod<void>('stop');
    } catch (_) {}
  }

  Future<void> streamPcmChunk(Uint8List pcmData, int sampleRate) async {
    if (pcmData.isEmpty) return;
    await _livePcm.invokeMethod<void>('write', {
      'data': pcmData,
      'sampleRate': sampleRate,
    });
  }

  Uint8List _pcmToWav(Uint8List pcmData, int sampleRate) {
    final byteRate = sampleRate * 2;
    final dataSize = pcmData.length;
    final header = ByteData(44);
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcmData);
    return wav;
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
    _player.dispose();
  }
}
