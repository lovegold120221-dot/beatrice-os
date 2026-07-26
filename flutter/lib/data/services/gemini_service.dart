import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'beatrice_persona.dart';

class GeminiService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String speechVoiceName = 'Kore';
  String apiKey;
  final String apiKeyFallback;
  bool _useFallback = false;

  GeminiService(this.apiKey, {this.apiKeyFallback = ''});

  String get _currentKey => _useFallback && apiKeyFallback.isNotEmpty
      ? apiKeyFallback
      : apiKey;

  void _rotateKey() {
    if (apiKeyFallback.isNotEmpty) {
      _useFallback = !_useFallback;
    }
  }

  bool _shouldRetry(int statusCode) =>
      statusCode == 429 || statusCode == 403;

  Uri _url(String model, String action) =>
      Uri.parse('$_baseUrl/models/$model:$action?key=$_currentKey');

  Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> body, {
    int retries = 1,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) return response;
      if (_shouldRetry(response.statusCode) && attempt < retries) {
        _rotateKey();
        continue;
      }
      return response;
    }
    throw Exception('Gemini API error after retries');
  }

  static const models = {
    'chat': 'gemini-2.5-flash',
    'fast': 'gemini-2.5-flash',
    'image': 'gemini-3.1-flash-image-preview',
    'imageBasic': 'gemini-2.5-flash-image',
    'imagePro': 'gemini-3-pro-image-preview',
    'audio': 'gemini-3-flash-preview',
    'tts': 'gemini-2.5-flash-preview-tts',
    'live': 'gemini-3.1-flash-live-preview',
  };

  static const String voicePersonalityPrompt = BeatricePersona.voicePrompt;

  static const String systemPrompt = BeatricePersona.chatPrompt;

  static const List<Map<String, dynamic>> toolDeclarations = [
    {
      'name': 'calculate',
      'description': 'Perform basic mathematical calculations.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'operation': {
            'type': 'STRING',
            'enum': ['add', 'subtract', 'multiply', 'divide'],
            'description': 'The mathematical operation to perform.',
          },
          'a': {'type': 'NUMBER', 'description': 'First operand.'},
          'b': {'type': 'NUMBER', 'description': 'Second operand.'},
        },
        'required': ['operation', 'a', 'b'],
      },
    },
    {
      'name': 'getCalendarEvents',
      'description': 'Get calendar events for a specific date.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'date': {
            'type': 'STRING',
            'description': 'The date in YYYY-MM-DD format.',
          },
        },
        'required': ['date'],
      },
    },
  ];

  static dynamic executeTool(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'calculate':
        final operation = args['operation'] as String;
        final a = (args['a'] as num).toDouble();
        final b = (args['b'] as num).toDouble();
        switch (operation) {
          case 'add':
            return {'result': a + b};
          case 'subtract':
            return {'result': a - b};
          case 'multiply':
            return {'result': a * b};
          case 'divide':
            return {'result': b != 0 ? a / b : 'Cannot divide by zero'};
          default:
            return {'error': 'Unknown operation'};
        }
      case 'getCalendarEvents':
        return {
          'events': [
            {'title': 'Meeting', 'time': '10:00 AM'},
            {'title': 'Lunch', 'time': '1:00 PM'},
          ],
        };
      default:
        return {'error': 'Unknown tool'};
    }
  }

  Future<Stream<String>> generateChatResponseStream({
    required String prompt,
    List<Map<String, dynamic>> history = const [],
    bool useThinking = false,
    bool useFast = false,
    String userContext = '',
    String responseStyle = '',
  }) async {
    String systemInstruction = systemPrompt;
    if (userContext.isNotEmpty) {
      systemInstruction +=
          '\n\nUser Context (What you should know about the user):\n$userContext';
    }
    if (responseStyle.isNotEmpty) {
      systemInstruction +=
          '\n\nResponse Style (How you should respond):\n$responseStyle';
    }

    final contents = _buildContents(history, prompt);
    final model = useFast ? models['fast']! : models['chat']!;

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      'tools': [
        {'functionDeclarations': toolDeclarations},
      ],
    };

    if (useThinking) {
      body['generationConfig'] = {
        'thinkingConfig': {'type': 'ENABLED'},
      };
    }

    http.StreamedResponse streamedResponse;
    for (int attempt = 0;; attempt++) {
      final req = http.Request('POST', _url(model, 'streamGenerateContent'));
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
      streamedResponse = await http.Client().send(req);
      if (streamedResponse.statusCode == 200) break;
      if (_shouldRetry(streamedResponse.statusCode) && attempt == 0) {
        _rotateKey();
        continue;
      }
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception(
        'Gemini API error: ${streamedResponse.statusCode} $errorBody',
      );
    }

    final controller = StreamController<String>();

    streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty) return;
            if (!line.startsWith('data: ')) return;
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              controller.close();
              return;
            }
            try {
              final chunk = jsonDecode(data);
              final candidates = chunk['candidates'] as List?;
              if (candidates == null || candidates.isEmpty) return;

              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts == null) return;

              for (final part in parts) {
                if (part['text'] != null) {
                  final text = part['text'] as String;
                  if (text.isNotEmpty) {
                    controller.add(text);
                  }
                }
              }
            } catch (_) {}
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
          onError: (e) {
            if (!controller.isClosed) {
              controller.addError(e);
              controller.close();
            }
          },
        );

    return controller.stream;
  }

  Future<String?> generateImage(
    String prompt, {
    String size = '1K',
    String aspectRatio = '1:1',
  }) async {
    final isBasic = size == '1K' && aspectRatio == '1:1';
    final model = isBasic ? models['imageBasic']! : models['image']!;

    final config = <String, dynamic>{
      'responseModalities': ['IMAGE', 'TEXT'],
      'imageConfig': {'aspectRatio': aspectRatio},
    };
    if (!isBasic) {
      config['imageConfig']!['imageSize'] = size;
    }

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': config,
    };

    final response = await _post(_url(model, 'generateContent'), body);
    if (response.statusCode != 200) {
      throw Exception('Image generation error: ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    final parts = result['candidates']?[0]?['content']?['parts'] as List?;
    if (parts != null) {
      for (final part in parts) {
        if (part['inlineData'] != null) {
          return 'data:image/png;base64,${part['inlineData']['data']}';
        }
      }
    }
    return null;
  }

  Future<String?> editImage(
    String prompt,
    String base64Data,
    String mimeType,
  ) async {
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'data': base64Data, 'mimeType': mimeType},
            },
            {'text': prompt},
          ],
        },
      ],
    };
    final response = await _post(
      _url(models['imageBasic']!, 'generateContent'),
      body,
    );
    if (response.statusCode != 200) {
      throw Exception('Edit image error: ${response.statusCode}');
    }
    final result = jsonDecode(response.body);
    final parts = result['candidates']?[0]?['content']?['parts'] as List?;
    if (parts != null) {
      for (final part in parts) {
        if (part['inlineData'] != null) {
          return 'data:image/png;base64,${part['inlineData']['data']}';
        }
      }
    }
    return null;
  }

  Future<String?> analyzeImage(
    String prompt,
    String base64Data,
    String mimeType,
  ) async {
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'data': base64Data, 'mimeType': mimeType},
            },
            {'text': prompt},
          ],
        },
      ],
    };
    final response = await _post(
      _url(models['chat']!, 'generateContent'),
      body,
    );
    if (response.statusCode != 200) {
      throw Exception('Analyze image error: ${response.statusCode}');
    }
    final result = jsonDecode(response.body);
    return result['candidates']?[0]?['content']?['parts']?[0]?['text']
        as String?;
  }

  Future<String?> textToSpeech(String text) async {
    final body = {
      'contents': [
        {
          'parts': [
            {'text': text},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': speechVoiceName},
          },
        },
      },
    };
    final response = await _post(
      _url(models['tts']!, 'generateContent'),
      body,
    );
    if (response.statusCode != 200) {
      throw Exception('TTS error: ${response.statusCode}');
    }
    final result = jsonDecode(response.body);
    final parts = result['candidates']?[0]?['content']?['parts'] as List?;
    if (parts != null) {
      for (final part in parts) {
        if (part['inlineData'] != null) {
          return 'data:audio/wav;base64,${part['inlineData']['data']}';
        }
      }
    }
    return null;
  }

  Future<String?> transcribeAudio(String base64Data, String mimeType) async {
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'data': base64Data, 'mimeType': mimeType},
            },
            {'text': 'Transcribe this audio exactly.'},
          ],
        },
      ],
    };
    final response = await _post(
      _url(models['audio']!, 'generateContent'),
      body,
    );
    if (response.statusCode != 200) {
      throw Exception('Transcribe error: ${response.statusCode}');
    }
    final result = jsonDecode(response.body);
    return result['candidates']?[0]?['content']?['parts']?[0]?['text']
        as String?;
  }

  List<Map<String, dynamic>> _buildContents(
    List<Map<String, dynamic>> history,
    String prompt,
  ) {
    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      contents.add({
        'role': m['role'],
        'parts': [
          {'text': m['parts']?[0]?['text'] ?? ''},
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });
    return contents;
  }
}
