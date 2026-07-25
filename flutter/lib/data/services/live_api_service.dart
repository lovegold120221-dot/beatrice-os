import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

enum LiveApiEventType {
  inputTranscription, // user speech (inputAudioTranscription)
  outputTranscription, // model speech text (modelTurn text parts / outputAudioTranscription)
  audioData, // model audio (modelTurn inlineData)
  turnComplete,
  interrupted, // barge-in: user spoke while model was talking
  error,
  done,
  toolCall,
}

class LiveApiEvent {
  final LiveApiEventType type;
  final String? text;
  final Uint8List? audioData;
  final int? sampleRate;
  final List<LiveFunctionCall> toolCalls;

  LiveApiEvent({
    required this.type,
    this.text,
    this.audioData,
    this.sampleRate,
    this.toolCalls = const [],
  });
}

class LiveFunctionCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const LiveFunctionCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class LiveApiService {
  static const _stableApiVersion = 'v1beta';
  static const _affectiveApiVersion = 'v1alpha';
  static const String aoedeVoiceName = 'Aoede';
  static const String conversationalActivityHandling = 'NO_INTERRUPTION';

  static const Map<String, dynamic> mobileTaskToolDeclaration = {
    'name': 'dispatch_mobile_task',
    'description':
        'Quietly hand one clarified, concise phone task to the app-owned '
        'execution coordinator while Beatrice continues the conversation. '
        'Use only for a genuine request to operate the phone or another '
        'Android app, and only after every execution-changing detail is '
        'known from the conversation. Never guess and never call it for '
        'ordinary conversation.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'task': {
          'type': 'STRING',
          'description':
              'One focused actionable task brief, no transcript or '
              'multi-step plan, maximum 800 characters. Preserve exact names, '
              'addresses, app/account, file, content, target, timing, and '
              'constraints supplied by the user; add nothing.',
        },
        'intentType': {
          'type': 'STRING',
          'enum': ['PHONE_TASK'],
          'description':
              'Explicit classification that the user requested an action on '
              'this phone or in an Android app.',
        },
        'essentialDetailsComplete': {
          'type': 'BOOLEAN',
          'description':
              'True only after required target, recipient, app/account, file, '
              'or requested action details are known without guessing.',
        },
      },
      'required': ['task', 'intentType', 'essentialDetailsComplete'],
    },
  };

  static const String secretaryHandoffInstruction = r'''
LIVE SECRETARY AND PHONE-TASK HANDOFF
Beatrice is the user's continuous conversational secretary. Gemini Live
understands speech and conversation; it never operates Android itself.

BASIS AND CLARIFICATION
- Base the user's intent only on words actually heard in this conversation and
  context explicitly supplied by the app. Never predict, assume, autocomplete,
  or choose a likely recipient, app, account, file, target, message, or intent.
- If audio or an execution-changing detail is unclear, ask one short,
  conversational question about that detail only. If a word was not heard
  clearly, ask the user to repeat that word or phrase. Do not call a tool yet.
- Keep details already understood. Never make the user repeat the whole request
  and never recite a formal summary merely to sound thorough.
- Do not mistake ordinary conversation, a hypothetical example, quoted speech,
  or a discussion about an app for a request to control the phone.

SEAMLESS SECRETARY BEHAVIOR
- Stay present in the conversation while handling the task, like a secretary
  quietly preparing work while still listening. Use one brief natural
  acknowledgment when useful; do not announce routing, JSON, tools, providers,
  models, MobileUseAgent, or an internal handoff.
- Once the phone-action intent and every essential detail are clear, create one
  compact actionable brief under 800 characters. Preserve the user's exact
  names, addresses, app/account, file, requested content, target, and
  constraints. Do not include filler, commentary, a raw transcript, guesses,
  or a multi-step plan.
- Call dispatch_mobile_task exactly once with intentType PHONE_TASK and
  essentialDetailsComplete true. The call means only that the app received the
  brief; it does not mean the task started or completed.
- Routine reversible actions may proceed without conversational ceremony.
  Sending, calling, purchasing, deleting, posting/submitting, or changing
  account/security state still requires the app's fresh detailed confirmation.
- Continue talking naturally if the user continues. Narrate task progress,
  failure, retry, approval, cancellation, and completion only from later
  coordinator-verified events. Never predict what the phone will do.
''';

  WebSocketChannel? _channel;
  StreamController<LiveApiEvent>? _eventController;
  bool _setupComplete = false;
  StreamSubscription? _subscription;
  Completer<void>? _setupCompleter;
  bool _disconnecting = false;

  bool get isConnected => _channel != null && _setupComplete;

  Future<Stream<LiveApiEvent>> connect({
    required String apiKey,
    required String model,
    required String systemInstruction,
    String voiceName = aoedeVoiceName,
    int clientSampleRate = 16000,
    int serverSampleRate = 24000,
    bool? enableAffectiveDialog,
  }) async {
    _disconnecting = false;
    _eventController?.close();
    _eventController = StreamController<LiveApiEvent>.broadcast();
    _setupComplete = false;
    _setupCompleter = Completer<void>();

    final useAffectiveDialog =
        enableAffectiveDialog ?? supportsAffectiveDialog(model);
    final apiVersion = useAffectiveDialog
        ? _affectiveApiVersion
        : _stableApiVersion;
    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.$apiVersion.GenerativeService'
      '.BidiGenerateContent'
      '?key=$apiKey',
    );

    _channel = WebSocketChannel.connect(uri);

    _subscription = _channel!.stream.listen(
      (data) => _onMessage(data),
      onError: (error) {
        final msg = error.toString();
        _eventController?.add(
          LiveApiEvent(type: LiveApiEventType.error, text: msg),
        );
        if (!_setupComplete &&
            _setupCompleter != null &&
            !_setupCompleter!.isCompleted) {
          _setupCompleter!.completeError(Exception(msg));
        }
      },
      onDone: () {
        if (!_disconnecting) {
          _eventController?.add(LiveApiEvent(type: LiveApiEventType.done));
        }
      },
    );

    _channel!.sink.add(
      jsonEncode(
        buildSetupPayload(
          model,
          systemInstruction,
          voiceName,
          clientSampleRate,
          serverSampleRate,
          enableAffectiveDialog: useAffectiveDialog,
        ),
      ),
    );

    await _setupCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('Live API setup timed out after 10s'),
    );

    return _eventController!.stream;
  }

  static bool supportsAffectiveDialog(String model) {
    final normalized = model.toLowerCase();
    return normalized.contains('gemini-2.5') &&
        normalized.contains('native-audio');
  }

  static Map<String, dynamic> buildSetupPayload(
    String model,
    String systemInstruction,
    String voiceName,
    int clientSampleRate,
    int serverSampleRate, {
    required bool enableAffectiveDialog,
  }) {
    return {
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          if (enableAffectiveDialog) 'enableAffectiveDialog': true,
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceName},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'tools': [
          {
            'functionDeclarations': [mobileTaskToolDeclaration],
          },
        ],
        'inputAudioTranscription': {},
        'outputAudioTranscription': {},
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'disabled': false,
            'startOfSpeechSensitivity': 'START_SENSITIVITY_HIGH',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_HIGH',
            'prefixPaddingMs': 40,
            'silenceDurationMs': 500,
          },
          // Let Aoede complete the current short sentence instead of having
          // server VAD cut the audio mid-word. The voice contract keeps turns
          // brief and requires an immediate yield after that sentence.
          'activityHandling': conversationalActivityHandling,
          'turnCoverage': 'TURN_INCLUDES_AUDIO_ACTIVITY_AND_ALL_VIDEO',
        },
      },
    };
  }

  void sendAudioChunk(Uint8List pcmData, {bool turnComplete = false}) {
    if (!_setupComplete) return;
    final msg = {
      'realtimeInput': {
        'mediaChunks': [
          {'mimeType': 'audio/pcm;rate=16000', 'data': base64Encode(pcmData)},
        ],
      },
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  void sendVideoFrame(Uint8List jpegData) {
    if (!_setupComplete || jpegData.isEmpty) return;
    _channel!.sink.add(
      jsonEncode({
        'realtimeInput': {
          'mediaChunks': [
            {'mimeType': 'image/jpeg', 'data': base64Encode(jpegData)},
          ],
        },
      }),
    );
  }

  void sendText(String text, {bool turnComplete = true}) {
    if (!_setupComplete) return;
    final msg = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': turnComplete,
      },
    };
    _channel!.sink.add(jsonEncode(msg));
  }

  void sendToolResponse({
    required String id,
    required String name,
    required Map<String, dynamic> response,
  }) {
    if (!_setupComplete) return;
    _channel!.sink.add(
      jsonEncode(
        buildToolResponsePayload(id: id, name: name, response: response),
      ),
    );
  }

  static Map<String, dynamic> buildToolResponsePayload({
    required String id,
    required String name,
    required Map<String, dynamic> response,
  }) {
    return {
      'toolResponse': {
        'functionResponses': [
          {'id': id, 'name': name, 'response': response},
        ],
      },
    };
  }

  static List<LiveFunctionCall> decodeToolCalls(Map<dynamic, dynamic> message) {
    final toolCall = message['toolCall'] ?? message['tool_call'];
    if (toolCall is! Map) return const [];
    final rawCalls =
        toolCall['functionCalls'] ?? toolCall['function_calls'] ?? const [];
    if (rawCalls is! List) return const [];
    final calls = <LiveFunctionCall>[];
    for (final rawCall in rawCalls) {
      if (rawCall is! Map) continue;
      final id = rawCall['id']?.toString().trim() ?? '';
      final name = rawCall['name']?.toString().trim() ?? '';
      final rawArgs = rawCall['args'] ?? rawCall['arguments'];
      if (id.isEmpty || name.isEmpty || rawArgs is! Map) continue;
      calls.add(
        LiveFunctionCall(
          id: id,
          name: name,
          arguments: Map<String, dynamic>.from(rawArgs),
        ),
      );
    }
    return calls;
  }

  // Tolerant getter: the raw BidiGenerateContent socket may emit either
  // camelCase (proto3 JSON default) or snake_case field names depending on
  // endpoint version. Accept both so parsing never silently drops events.
  dynamic _pick(Map obj, String camel, String snake) {
    if (obj.containsKey(camel)) return obj[camel];
    if (obj.containsKey(snake)) return obj[snake];
    return null;
  }

  void _onMessage(dynamic data) {
    final String text;
    if (data is String) {
      text = data;
    } else if (data is Uint8List) {
      text = utf8.decode(data);
    } else {
      return;
    }

    try {
      final msg = jsonDecode(text) as Map;

      final apiError = msg['error'];
      if (apiError != null) {
        final errorText = apiError is Map
            ? (apiError['message']?.toString() ?? apiError.toString())
            : apiError.toString();
        _eventController?.add(
          LiveApiEvent(type: LiveApiEventType.error, text: errorText),
        );
        if (!_setupComplete &&
            _setupCompleter != null &&
            !_setupCompleter!.isCompleted) {
          _setupCompleter!.completeError(Exception(errorText));
        }
        return;
      }

      if (msg['setupComplete'] != null || msg['setup_complete'] != null) {
        _setupComplete = true;
        if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
          _setupCompleter!.complete();
        }
        return;
      }

      final toolCalls = decodeToolCalls(msg);
      if (toolCalls.isNotEmpty) {
        _eventController?.add(
          LiveApiEvent(type: LiveApiEventType.toolCall, toolCalls: toolCalls),
        );
        return;
      }

      final serverContent = _pick(msg, 'serverContent', 'server_content');
      if (serverContent is! Map) return;

      final turnComplete =
          _pick(serverContent, 'turnComplete', 'turn_complete') == true;
      final interrupted =
          _pick(serverContent, 'interrupted', 'interrupted') == true;

      // User speech transcription (what the user said).
      final inputTranscription = _pick(
        serverContent,
        'inputAudioTranscription',
        'input_audio_transcription',
      );
      if (inputTranscription is Map && inputTranscription['text'] != null) {
        _eventController?.add(
          LiveApiEvent(
            type: LiveApiEventType.inputTranscription,
            text: inputTranscription['text'] as String,
          ),
        );
      }

      // Model turn: audio + (optionally) output transcription text.
      final modelTurn = _pick(serverContent, 'modelTurn', 'model_turn');
      if (modelTurn is Map) {
        final parts = modelTurn['parts'] as List? ?? [];
        for (final part in parts) {
          if (part is! Map) continue;
          // Inline audio (model speaking).
          final inlineData = _pick(part, 'inlineData', 'inline_data');
          if (inlineData is Map) {
            final b64 = inlineData['data'] as String?;
            if (b64 != null) {
              final mime =
                  inlineData['mime_type'] as String? ??
                  inlineData['mimeType'] as String? ??
                  'audio/pcm;rate=24000';
              int rate = 24000;
              final rateMatch = RegExp(r'rate=(\d+)').firstMatch(mime);
              if (rateMatch != null) {
                rate = int.tryParse(rateMatch.group(1)!) ?? 24000;
              }
              _eventController?.add(
                LiveApiEvent(
                  type: LiveApiEventType.audioData,
                  audioData: Uint8List.fromList(base64Decode(b64)),
                  sampleRate: rate,
                ),
              );
            }
          }
          // Output transcription text (what the model said).
          if (part['text'] != null) {
            _eventController?.add(
              LiveApiEvent(
                type: LiveApiEventType.outputTranscription,
                text: part['text'] as String,
              ),
            );
          }
        }
      }

      // Standalone output transcription (some payloads emit it outside modelTurn).
      final outputTranscription = _pick(
        serverContent,
        'outputAudioTranscription',
        'output_audio_transcription',
      );
      if (outputTranscription is Map && outputTranscription['text'] != null) {
        _eventController?.add(
          LiveApiEvent(
            type: LiveApiEventType.outputTranscription,
            text: outputTranscription['text'] as String,
          ),
        );
      }

      if (interrupted) {
        _eventController?.add(LiveApiEvent(type: LiveApiEventType.interrupted));
      }

      if (turnComplete) {
        _eventController?.add(
          LiveApiEvent(type: LiveApiEventType.turnComplete),
        );
      }
    } catch (_) {}
  }

  void disconnect() {
    _disconnecting = true;
    _setupComplete = false;
    if (_setupCompleter != null && !_setupCompleter!.isCompleted) {
      _setupCompleter!.completeError(Exception('Disconnected'));
    }
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _eventController?.close();
    _eventController = null;
  }
}
