import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'beatrice_persona.dart';

class OllamaDiscoveryResult {
  final String? endpoint;
  final List<String> models;
  final String? error;
  final String? version;
  final List<String> attempts;

  const OllamaDiscoveryResult({
    required this.endpoint,
    required this.models,
    this.error,
    this.version,
    this.attempts = const [],
  });

  bool get isConnected => endpoint != null;

  String get status {
    if (!isConnected) {
      return error ?? 'Ollama is not reachable';
    }
    if (models.isEmpty) {
      return 'Connected to $endpoint, but Ollama reports no installed models';
    }
    return 'Connected to $endpoint'
        '${version == null ? '' : ' (Ollama $version)'} — ${models.length} '
        'model${models.length == 1 ? '' : 's'} available';
  }
}

class OllamaModelCapabilities {
  final bool tools;
  final bool vision;

  const OllamaModelCapabilities({required this.tools, required this.vision});
}

class WebLookupResult {
  final String query;
  final String summary;
  final List<String> sourceUrls;

  const WebLookupResult({
    required this.query,
    required this.summary,
    required this.sourceUrls,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'summary': summary,
    'sources': sourceUrls,
  };
}

typedef WebLookup = Future<WebLookupResult> Function(String query);
typedef LocalOcr = Future<Map<String, dynamic>> Function();

/// Ollama chat service.
///
/// `baseUrl` is mutable so the user can point at a local Termux Ollama
/// (`http://127.0.0.1:11434`) or any remote host from Settings. Cleartext
/// HTTP to localhost is permitted by the Android manifest
/// (`usesCleartextTraffic="true"`), which is what Termux needs.
class OllamaService {
  String baseUrl;
  String defaultModel;
  bool isCloud;
  String? apiKey;
  final http.Client _client;

  OllamaService({
    this.baseUrl = 'http://127.0.0.1:11434',
    this.defaultModel = 'codemax-beta:latest',
    this.isCloud = false,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  void configure({
    String? baseUrl,
    String? defaultModel,
    bool? isCloud,
    String? apiKey,
  }) {
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      this.baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (defaultModel != null && defaultModel.trim().isNotEmpty) {
      this.defaultModel = defaultModel.trim();
    }
    if (isCloud != null) this.isCloud = isCloud;
    if (apiKey != null) this.apiKey = apiKey.trim();
  }

  Uri _uri(String path, {String? host}) {
    final root = (host ?? baseUrl).replaceAll(RegExp(r'/+$'), '');
    final suffix = root.endsWith('/api')
        ? path.replaceFirst(RegExp(r'^/api'), '')
        : path;
    return Uri.parse('$root$suffix');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (isCloud && (apiKey?.isNotEmpty ?? false))
      'Authorization': 'Bearer $apiKey',
  };

  static const String systemPrompt = BeatricePersona.chatPrompt;

  /// Lightweight reachability check used by the Settings "Test connection"
  /// button. Returns a human-readable status string.
  Future<String> ping() async {
    return (await discoverModels()).status;
  }

  Future<List<String>> listModels() async {
    final result = await discoverModels();
    if (result.endpoint != null) {
      configure(baseUrl: result.endpoint);
    }
    return result.models;
  }

  Future<OllamaModelCapabilities> modelCapabilities(String model) async {
    final response = await _client
        .post(
          _uri('/api/show'),
          headers: _headers,
          body: jsonEncode({'model': model, 'verbose': false}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Unable to inspect model capabilities.');
    }
    final decoded = jsonDecode(response.body);
    final values = decoded is Map && decoded['capabilities'] is List
        ? (decoded['capabilities'] as List)
              .map((value) => value.toString().toLowerCase())
              .toSet()
        : <String>{};
    return OllamaModelCapabilities(
      tools: values.contains('tools') || values.contains('tool'),
      vision: values.contains('vision'),
    );
  }

  /// Finds a reachable Ollama server without assuming that a saved remote URL
  /// is still valid. Android apps and Termux share the device loopback network,
  /// so the standard local aliases are safe discovery candidates.
  Future<OllamaDiscoveryResult> discoverModels({
    Iterable<String>? candidates,
  }) async {
    if (isCloud && (apiKey?.isEmpty ?? true)) {
      return const OllamaDiscoveryResult(
        endpoint: null,
        models: [],
        error: 'Ollama Cloud API key is required. Add it in Settings.',
      );
    }
    final endpoints = isCloud
        ? <String>{_normalizeBaseUrl(baseUrl)}
        : <String>{
            'http://127.0.0.1:11434',
            'http://localhost:11434',
            'http://[::1]:11434',
            _normalizeBaseUrl(baseUrl),
            if (candidates != null) ...candidates.map(_normalizeBaseUrl),
          };
    final attempts = <String>[];

    for (final endpoint in endpoints.where((value) => value.isNotEmpty)) {
      for (var retry = 0; retry < 2; retry++) {
        try {
          final response = await _client
              .get(_uri('/api/tags', host: endpoint), headers: _headers)
              .timeout(const Duration(seconds: 2));
          if (response.statusCode != 200) {
            attempts.add('$endpoint/api/tags: HTTP ${response.statusCode}');
            break;
          }

          final data = jsonDecode(response.body);
          if (data is! Map<String, dynamic>) {
            attempts.add('$endpoint/api/tags: invalid JSON object');
            break;
          }
          final entries = data['models'];
          if (entries is! List) {
            attempts.add('$endpoint/api/tags: missing models array');
            break;
          }

          final models = <String>[];
          for (final entry in entries) {
            if (entry is! Map) continue;
            final name = entry['name']?.toString().trim() ?? '';
            if (name.isNotEmpty && !models.contains(name)) models.add(name);
          }
          String? version;
          try {
            final versionResponse = await _client
                .get(_uri('/api/version', host: endpoint), headers: _headers)
                .timeout(const Duration(seconds: 2));
            if (versionResponse.statusCode == 200) {
              final versionJson = jsonDecode(versionResponse.body);
              if (versionJson is Map) {
                version = versionJson['version']?.toString();
              }
            } else {
              attempts.add(
                '$endpoint/api/version: HTTP ${versionResponse.statusCode}',
              );
            }
          } catch (error) {
            attempts.add('$endpoint/api/version: $error');
          }
          return OllamaDiscoveryResult(
            endpoint: endpoint,
            models: models,
            version: version,
            attempts: attempts,
          );
        } catch (error) {
          attempts.add('$endpoint/api/tags: $error');
          if (retry == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
      }
    }

    return OllamaDiscoveryResult(
      endpoint: null,
      models: const [],
      attempts: attempts,
      error:
          'Ollama is not reachable from the app. In Termux run '
          '`OLLAMA_HOST=127.0.0.1:11434 ollama serve`, keep that session open, '
          'then tap Refresh. Probes: ${attempts.join(' | ')}',
    );
  }

  String _normalizeBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<Stream<String>> generateChatResponseStream({
    required String prompt,
    List<Map<String, dynamic>> history = const [],
    String userContext = '',
    String responseStyle = '',
    String? modelOverride,
  }) async {
    final model = (modelOverride != null && modelOverride.isNotEmpty)
        ? modelOverride
        : defaultModel;
    String systemContent = systemPrompt;
    if (userContext.isNotEmpty) {
      systemContent +=
          '\n\nUser Context (What you should know about the user):\n$userContext';
    }
    if (responseStyle.isNotEmpty) {
      systemContent +=
          '\n\nResponse Style (How you should respond):\n$responseStyle';
    }

    final messages = <Map<String, dynamic>>[];
    messages.add({'role': 'system', 'content': systemContent});

    for (final m in history) {
      final text = m['parts']?[0]?['text'] as String? ?? '';
      if (text.isEmpty) continue;
      final role = m['role'] == 'user' ? 'user' : 'assistant';
      messages.add({'role': role, 'content': text});
    }
    messages.add({'role': 'user', 'content': prompt});

    final request = http.Request('POST', _uri('/api/chat'));
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
    });

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception(
        'Ollama API error: ${streamedResponse.statusCode} $errorBody',
      );
    }

    final controller = StreamController<String>();

    streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty) return;
            try {
              final obj = jsonDecode(line);
              final text = obj['message']?['content'] as String? ?? '';
              if (text.isNotEmpty) {
                controller.add(text);
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

  /// Uses Ollama's native `/api/chat` message, vision, and function-tool
  /// contract. The app executes the allowlisted tool and returns its structured
  /// result as a `role: tool` follow-up; the model never gets network access.
  Future<String> generateChatWithTools({
    required String prompt,
    required String model,
    List<Map<String, dynamic>> history = const [],
    List<String> base64Images = const [],
    bool enableWebLookup = false,
    WebLookup? webLookup,
    bool enableLocalOcr = false,
    LocalOcr? localOcr,
    String userContext = '',
    String responseStyle = '',
  }) async {
    final capabilities = await modelCapabilities(model);
    if (base64Images.isNotEmpty && !capabilities.vision) {
      throw Exception(
        '"$model" does not advertise Ollama vision support. '
        'Select an installed vision model such as Gemma 3.',
      );
    }
    if (enableWebLookup && !capabilities.tools) {
      throw Exception(
        '"$model" does not advertise Ollama tool support. '
        'Choose a tool-capable installed model or turn Web off.',
      );
    }

    var system = systemPrompt;
    if (userContext.isNotEmpty) {
      system += '\n\nUser context:\n$userContext';
    }
    if (responseStyle.isNotEmpty) {
      system += '\n\nResponse style:\n$responseStyle';
    }
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      ...history
          .map((m) {
            final text = m['parts']?[0]?['text']?.toString() ?? '';
            return {
              'role': m['role'] == 'user' ? 'user' : 'assistant',
              'content': text,
            };
          })
          .where((m) => (m['content'] as String).isNotEmpty),
      {
        'role': 'user',
        'content': prompt,
        if (base64Images.isNotEmpty) 'images': base64Images,
      },
    ];
    final tools = <Map<String, dynamic>>[
      if (enableWebLookup)
        {
          'type': 'function',
          'function': {
            'name': 'web_lookup',
            'description':
                'Search the public web only when current information is '
                'needed. Returns a short attributed summary.',
            'parameters': {
              'type': 'object',
              'required': ['query'],
              'properties': {
                'query': {
                  'type': 'string',
                  'description': 'A concise web search query',
                },
              },
            },
          },
        },
      if (enableLocalOcr)
        {
          'type': 'function',
          'function': {
            'name': 'extract_text',
            'description':
                'Run private on-device Tesseract OCR on the image document '
                'the user explicitly selected. Use this before answering '
                'questions about text in that image.',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
    ];
    final attributedSources = <String>[];

    for (var pass = 0; pass < 3; pass++) {
      final response = await _postChat(model, messages, tools);
      final message = response['message'];
      if (message is! Map) {
        throw const FormatException('Ollama returned an invalid chat message.');
      }
      final calls = message['tool_calls'];
      if (calls is! List || calls.isEmpty) {
        final content = message['content']?.toString().trim() ?? '';
        if (content.isEmpty) {
          throw const FormatException('Ollama returned an empty response.');
        }
        if (attributedSources.isEmpty) return content;
        return '$content\n\nSources:\n'
            '${attributedSources.map((url) => '- $url').join('\n')}';
      }
      messages.add(Map<String, dynamic>.from(message));
      for (final rawCall in calls) {
        final function = rawCall is Map ? rawCall['function'] : null;
        final name = function is Map ? function['name']?.toString() : null;
        final arguments = function is Map ? function['arguments'] : null;
        if (name == 'web_lookup' && enableWebLookup && webLookup != null) {
          final query = arguments is Map
              ? arguments['query']?.toString().trim() ?? ''
              : '';
          if (query.isEmpty || query.length > 300) {
            throw const FormatException(
              'Ollama supplied an invalid web query.',
            );
          }
          final result = await webLookup(query);
          attributedSources.addAll(
            result.sourceUrls.where((url) => !attributedSources.contains(url)),
          );
          messages.add({
            'role': 'tool',
            'tool_name': 'web_lookup',
            'content': jsonEncode(result.toJson()),
          });
        } else if (name == 'extract_text' &&
            enableLocalOcr &&
            localOcr != null) {
          messages.add({
            'role': 'tool',
            'tool_name': 'extract_text',
            'content': jsonEncode(await localOcr()),
          });
        } else {
          throw Exception('Ollama requested an unavailable tool: $name');
        }
      }
    }
    throw Exception('Ollama exceeded the bounded web-tool follow-up limit.');
  }

  Future<Map<String, dynamic>> _postChat(
    String model,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    final response = await _client
        .post(
          _uri('/api/chat'),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
            if (tools.isNotEmpty) 'tools': tools,
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw Exception(
        'Ollama chat failed with HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ollama returned invalid JSON.');
    }
    return decoded;
  }

  /// One bounded, non-streaming JSON response for the local mobile planner.
  /// Uses the explicitly selected Ollama provider; it never falls back between
  /// local and cloud.
  Future<String> generatePlannerCommand({
    required String prompt,
    required String model,
  }) async {
    final response = await _client
        .post(
          _uri('/api/generate'),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'stream': false,
            'format': 'json',
            'keep_alive': '10m',
            'options': {
              'temperature': 0.1,
              'top_p': 0.8,
              'num_predict': 300,
              'num_ctx': 2048,
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw Exception(
        'Ollama planner failed with HTTP ${response.statusCode}: '
        '${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['response'] is! String) {
      throw const FormatException(
        'Ollama returned an invalid planner response.',
      );
    }
    return decoded['response'] as String;
  }
}
