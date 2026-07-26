import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mobile_planner_provider.dart';

class HostedPlannerDiscovery {
  final List<String> models;
  final String status;
  final String? error;

  const HostedPlannerDiscovery({
    this.models = const [],
    required this.status,
    this.error,
  });

  bool get isConnected => error == null;
}

/// Authenticated online planner adapters used only by MobileUseAgent.
///
/// Keys are supplied by the app from encrypted device storage and are never
/// logged or included in Supabase profile rows.
class HostedPlannerService {
  static const _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const _groqBaseUrl = 'https://api.groq.com/openai/v1';

  final http.Client _client;
  final Duration timeout;
  String providerId;
  String apiKey;

  HostedPlannerService({
    required this.providerId,
    this.apiKey = '',
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client() {
    _requireSupportedProvider(providerId);
  }

  void configure({String? providerId, String? apiKey}) {
    if (providerId != null) {
      _requireSupportedProvider(providerId);
      this.providerId = providerId;
    }
    if (apiKey != null) this.apiKey = apiKey.trim();
  }

  Future<HostedPlannerDiscovery> discoverModels() async {
    if (apiKey.trim().isEmpty) {
      return HostedPlannerDiscovery(
        status: '${_providerLabel(providerId)} API key required',
        error:
            'Enter a ${_providerLabel(providerId)} API key, then refresh models.',
      );
    }
    try {
      final models = providerId == MobilePlannerProviders.gemini
          ? await _discoverGeminiModels()
          : await _discoverGroqModels();
      return HostedPlannerDiscovery(
        models: models,
        status: models.isEmpty
            ? '${_providerLabel(providerId)} connected, but no compatible '
                  'models were returned.'
            : '${_providerLabel(providerId)} connected · '
                  '${models.length} models available',
      );
    } on TimeoutException {
      return HostedPlannerDiscovery(
        status: '${_providerLabel(providerId)} request timed out',
        error: 'The provider did not respond within ${timeout.inSeconds}s.',
      );
    } catch (error) {
      final message = _compactError(error);
      return HostedPlannerDiscovery(status: message, error: message);
    }
  }

  Future<String> generatePlannerCommand({
    required String prompt,
    required String model,
  }) async {
    final key = apiKey.trim();
    final selectedModel = model.trim();
    if (key.isEmpty) {
      throw StateError('${_providerLabel(providerId)} API key is missing.');
    }
    if (selectedModel.isEmpty) {
      throw StateError('${_providerLabel(providerId)} model is not selected.');
    }
    return providerId == MobilePlannerProviders.gemini
        ? _generateGemini(prompt, selectedModel, key)
        : _generateGroq(prompt, selectedModel, key);
  }

  Future<List<String>> _discoverGeminiModels() async {
    final uri = Uri.parse(
      '$_geminiBaseUrl/models',
    ).replace(queryParameters: {'pageSize': '1000', 'key': apiKey.trim()});
    final response = await _client.get(uri).timeout(timeout);
    final body = _decodeObject(response);
    _throwForStatus(response, body, 'Gemini model discovery');
    final models = <String>{};
    for (final entry in (body['models'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final methods = (entry['supportedGenerationMethods'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet();
      if (!methods.contains('generateContent')) continue;
      final name = entry['name']?.toString().replaceFirst('models/', '') ?? '';
      if (name.isNotEmpty) models.add(name);
    }
    final sorted = models.toList()..sort();
    return sorted;
  }

  Future<List<String>> _discoverGroqModels() async {
    final response = await _client
        .get(
          Uri.parse('$_groqBaseUrl/models'),
          headers: {'Authorization': 'Bearer ${apiKey.trim()}'},
        )
        .timeout(timeout);
    final body = _decodeObject(response);
    _throwForStatus(response, body, 'Groq model discovery');
    final models = <String>{};
    for (final entry in (body['data'] as List? ?? const [])) {
      if (entry is! Map || entry['active'] == false) continue;
      final id = entry['id']?.toString() ?? '';
      if (_isGroqPlannerCandidate(id)) models.add(id);
    }
    final sorted = models.toList()..sort();
    return sorted;
  }

  Future<String> _generateGemini(
    String prompt,
    String model,
    String key,
  ) async {
    final uri = Uri.parse(
      '$_geminiBaseUrl/models/${Uri.encodeComponent(model)}:generateContent',
    ).replace(queryParameters: {'key': key});
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0,
              'maxOutputTokens': 1024,
              'responseMimeType': 'application/json',
            },
          }),
        )
        .timeout(timeout);
    final body = _decodeObject(response);
    _throwForStatus(response, body, 'Gemini planning');
    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty || candidates.first is! Map) {
      throw StateError('Gemini returned no planner candidate.');
    }
    final content = (candidates.first as Map)['content'];
    final parts = content is Map
        ? content['parts'] as List? ?? const []
        : const [];
    final text = parts
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .join()
        .trim();
    if (text.isEmpty) {
      throw StateError('Gemini returned an empty planner command.');
    }
    return text;
  }

  Future<String> _generateGroq(String prompt, String model, String key) async {
    final response = await _client
        .post(
          Uri.parse('$_groqBaseUrl/chat/completions'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Return exactly one valid JSON object. Never return prose, '
                    'markdown, code fences, or shell commands.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0,
            'max_completion_tokens': 1024,
            'stream': false,
          }),
        )
        .timeout(timeout);
    final body = _decodeObject(response);
    _throwForStatus(response, body, 'Groq planning');
    final choices = body['choices'] as List? ?? const [];
    if (choices.isEmpty || choices.first is! Map) {
      throw StateError('Groq returned no planner choice.');
    }
    final message = (choices.first as Map)['message'];
    final text = message is Map
        ? message['content']?.toString().trim() ?? ''
        : '';
    if (text.isEmpty) {
      throw StateError('Groq returned an empty planner command.');
    }
    return text;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{'raw': response.body};
    }
  }

  void _throwForStatus(
    http.Response response,
    Map<String, dynamic> body,
    String operation,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final nestedError = body['error'];
    final detail = nestedError is Map
        ? nestedError['message']?.toString()
        : nestedError?.toString();
    final safeDetail = (detail?.trim().isNotEmpty ?? false)
        ? detail!.trim()
        : 'HTTP ${response.statusCode}';
    throw StateError('$operation failed: $safeDetail');
  }

  static bool _isGroqPlannerCandidate(String id) {
    if (id.trim().isEmpty) return false;
    final normalized = id.toLowerCase();
    const unsupportedTerms = [
      'whisper',
      'tts',
      'guard',
      'safeguard',
      'prompt-guard',
    ];
    return !unsupportedTerms.any(normalized.contains);
  }

  String _compactError(Object error) {
    final compact = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Bad state):\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final secret = apiKey.trim();
    return secret.isEmpty ? compact : compact.replaceAll(secret, '[redacted]');
  }

  static void _requireSupportedProvider(String providerId) {
    if (providerId != MobilePlannerProviders.gemini &&
        providerId != MobilePlannerProviders.groq) {
      throw ArgumentError.value(
        providerId,
        'providerId',
        'Hosted planner must be Gemini or Groq.',
      );
    }
  }

  static String _providerLabel(String providerId) =>
      MobilePlannerProviders.byId(providerId).label;
}
