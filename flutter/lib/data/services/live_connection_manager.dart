import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:beatrice/data/services/live_api_service.dart';

enum ConnectionState { disconnected, connecting, connected, reconnecting, failed }

class LiveConnectionManager {
  static const _initialBackoffMs = 500;
  static const _maxBackoffMs = 8000;
  static const _backoffMultiplier = 2.0;
  static const _maxRetries = 3;
  static const _heartbeatInterval = Duration(seconds: 8);

  final LiveApiService _liveApi;
  ConnectionState _state = ConnectionState.disconnected;
  Timer? _heartbeatTimer;
  int _consecutiveHeartbeatFailures = 0;
  StreamController<LiveApiEvent>? _outputController;

  LiveConnectionManager(this._liveApi);
  ConnectionState get state => _state;

  Future<Stream<LiveApiEvent>> connect({
    required String apiKey,
    required String model,
    required String systemInstruction,
    String voiceName = LiveApiService.koreVoiceName,
    String? languageCode,
    int clientSampleRate = 16000,
    int serverSampleRate = 24000,
    bool? enableAffectiveDialog,
  }) async {
    _state = ConnectionState.connecting;
    _consecutiveHeartbeatFailures = 0;
    _outputController?.close();
    _outputController = StreamController<LiveApiEvent>.broadcast();

    Stream<LiveApiEvent>? stream;
    Object? lastError;

    try {
      stream = await _liveApi.connect(
        apiKey: apiKey, model: model, systemInstruction: systemInstruction,
        voiceName: voiceName, languageCode: languageCode,
        clientSampleRate: clientSampleRate, serverSampleRate: serverSampleRate,
        enableAffectiveDialog: enableAffectiveDialog,
        enableProactiveAudio: enableProactiveAudio,
      );
    } catch (e) {
      lastError = e;
      debugPrint('[LiveConnectionManager] Initial connect failed: $e');
    }

    if (stream == null) {
      _state = ConnectionState.reconnecting;
      var delayMs = _initialBackoffMs;
      for (var attempt = 1; attempt <= _maxRetries; attempt++) {
        _outputController!.add(LiveApiEvent(
          type: LiveApiEventType.error,
          text: 'Reconnecting (attempt $attempt/$_maxRetries)...',
        ));
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs = (delayMs * _backoffMultiplier).toInt().clamp(0, _maxBackoffMs);
        try {
          stream = await _liveApi.connect(
            apiKey: apiKey, model: model, systemInstruction: systemInstruction,
            voiceName: voiceName, languageCode: languageCode,
            clientSampleRate: clientSampleRate, serverSampleRate: serverSampleRate,
            enableAffectiveDialog: enableAffectiveDialog,
            enableProactiveAudio: enableProactiveAudio,
          );
          break;
        } catch (e) {
          lastError = e;
          debugPrint('[LiveConnectionManager] Retry $attempt failed: $e');
        }
      }
    }

    if (stream == null) {
      _state = ConnectionState.failed;
      _outputController!.add(LiveApiEvent(type: LiveApiEventType.done));
      throw lastError ?? Exception('Connection failed');
    }

    _state = ConnectionState.connected;
    stream.listen(
      (event) => _outputController?.add(event),
      onError: (e) => _outputController?.add(
        LiveApiEvent(type: LiveApiEventType.error, text: e.toString()),
      ),
      onDone: () {
        if (_state != ConnectionState.disconnected) {
          _state = ConnectionState.disconnected;
          _stopHeartbeat();
        }
      },
    );
    _startHeartbeat();
    return _outputController!.stream;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (_state != ConnectionState.connected) return;
      try {
        if (!_liveApi.isConnected) {
          _consecutiveHeartbeatFailures++;
          debugPrint(
            '[LiveConnectionManager] Heartbeat fail '
            '($_consecutiveHeartbeatFailures/2)',
          );
          if (_consecutiveHeartbeatFailures >= 2) {
            debugPrint('[LiveConnectionManager] Heartbeat lost, disconnecting');
            await disconnect();
            _outputController?.add(LiveApiEvent(type: LiveApiEventType.done));
          }
        } else {
          _consecutiveHeartbeatFailures = 0;
        }
      } catch (_) {
        _consecutiveHeartbeatFailures++;
        if (_consecutiveHeartbeatFailures >= 2) {
          await disconnect();
          _outputController?.add(LiveApiEvent(type: LiveApiEventType.done));
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _state = ConnectionState.disconnected;
    _consecutiveHeartbeatFailures = 0;
    _liveApi.disconnect();
    await _outputController?.close();
    _outputController = null;
  }

  void dispose() {
    _stopHeartbeat();
    _outputController?.close();
    _outputController = null;
  }
}
