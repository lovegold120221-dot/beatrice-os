import 'package:beatrice/data/services/ollama_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('discovers exact model names returned by Ollama', () async {
    final service = OllamaService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/tags');
        return http.Response(
          '{"models":['
          '{"name":"deepseek-r1:7b"},'
          '{"name":"qwen3:latest"},'
          '{"name":"deepseek-r1:7b"}'
          ']}',
          200,
        );
      }),
    );

    final result = await service.discoverModels();

    expect(result.isConnected, isTrue);
    expect(result.models, ['deepseek-r1:7b', 'qwen3:latest']);
  });

  test('falls back from a stale URL to Android loopback', () async {
    final service = OllamaService(
      baseUrl: 'http://192.0.2.1:11434',
      client: MockClient((request) async {
        if (request.url.host == '127.0.0.1') {
          return http.Response(
            '{"models":[{"name":"deepseek-r1:latest"}]}',
            200,
          );
        }
        throw Exception('connection refused');
      }),
    );

    final result = await service.discoverModels();

    expect(result.endpoint, 'http://127.0.0.1:11434');
    expect(result.models, ['deepseek-r1:latest']);
  });

  test('distinguishes a reachable server with no installed models', () async {
    final service = OllamaService(
      client: MockClient((_) async => http.Response('{"models":[]}', 200)),
    );

    final result = await service.discoverModels();

    expect(result.isConnected, isTrue);
    expect(result.models, isEmpty);
    expect(result.status, contains('no installed models'));
  });

  test(
    'cloud discovery uses API root and bearer auth without local fallback',
    () async {
      final requests = <http.Request>[];
      final service = OllamaService(
        baseUrl: 'https://ollama.com/api',
        isCloud: true,
        apiKey: 'test-secret',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.url.host, 'ollama.com');
          expect(request.headers['authorization'], 'Bearer test-secret');
          if (request.url.path == '/api/version') {
            return http.Response('{"version":"cloud"}', 200);
          }
          expect(request.url.path, '/api/tags');
          return http.Response('{"models":[{"name":"gpt-oss:120b"}]}', 200);
        }),
      );

      final result = await service.discoverModels();

      expect(result.models, ['gpt-oss:120b']);
      expect(requests.map((request) => request.url.host).toSet(), {
        'ollama.com',
      });
    },
  );

  test('cloud discovery refuses missing key without network request', () async {
    var called = false;
    final service = OllamaService(
      baseUrl: 'https://ollama.com/api',
      isCloud: true,
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 500);
      }),
    );

    final result = await service.discoverModels();

    expect(result.isConnected, isFalse);
    expect(result.error, contains('API key'));
    expect(called, isFalse);
  });

  test('uses native tool call and returns attributed result to Ollama', () async {
    var chatCalls = 0;
    final service = OllamaService(
      client: MockClient((request) async {
        if (request.url.path == '/api/show') {
          return http.Response('{"capabilities":["tools"]}', 200);
        }
        expect(request.url.path, '/api/chat');
        chatCalls++;
        final body = request.body;
        if (chatCalls == 1) {
          expect(body, contains('"name":"web_lookup"'));
          return http.Response(
            '{"message":{"role":"assistant","content":"","tool_calls":['
            '{"function":{"name":"web_lookup","arguments":{"query":"Flutter"}}}'
            ']}}',
            200,
          );
        }
        expect(body, contains('"role":"tool"'));
        expect(body, contains('https://example.test/flutter'));
        return http.Response(
          '{"message":{"role":"assistant","content":"Flutter summary [1]"}}',
          200,
        );
      }),
    );

    final answer = await service.generateChatWithTools(
      prompt: 'What is new with Flutter?',
      model: 'qwen3',
      enableWebLookup: true,
      webLookup: (query) async => WebLookupResult(
        query: query,
        summary: 'Attributed summary',
        sourceUrls: const ['https://example.test/flutter'],
      ),
    );

    expect(answer, contains('Flutter summary [1]'));
    expect(answer, contains('https://example.test/flutter'));
    expect(chatCalls, 2);
  });

  test('rejects images for a text-only model before chat', () async {
    final service = OllamaService(
      client: MockClient(
        (_) async => http.Response('{"capabilities":["completion"]}', 200),
      ),
    );

    expect(
      () => service.generateChatWithTools(
        prompt: 'Describe this',
        model: 'qwen2.5:0.5b',
        base64Images: const ['abc'],
      ),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'returns genuine local OCR result through native Ollama tool loop',
    () async {
      var chatCalls = 0;
      final service = OllamaService(
        client: MockClient((request) async {
          if (request.url.path == '/api/show') {
            return http.Response('{"capabilities":["tools"]}', 200);
          }
          chatCalls++;
          if (chatCalls == 1) {
            return http.Response(
              '{"message":{"role":"assistant","content":"","tool_calls":['
              '{"function":{"name":"extract_text","arguments":{}}}]}}',
              200,
            );
          }
          expect(request.body, contains('"tool_name":"extract_text"'));
          expect(request.body, contains('Invoice total'));
          return http.Response(
            '{"message":{"role":"assistant","content":"The total is 42."}}',
            200,
          );
        }),
      );

      final answer = await service.generateChatWithTools(
        prompt: 'Read this document',
        model: 'qwen3',
        enableLocalOcr: true,
        localOcr: () async => {
          'text': 'Invoice total: 42',
          'meanConfidence': 92,
          'language': 'eng',
          'engine': 'Tesseract',
        },
      );

      expect(answer, 'The total is 42.');
      expect(chatCalls, 2);
    },
  );
}
