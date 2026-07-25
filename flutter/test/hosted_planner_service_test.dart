import 'package:beatrice/data/services/hosted_planner_service.dart';
import 'package:beatrice/data/services/mobile_planner_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Gemini discovers only generateContent models', () async {
    final service = HostedPlannerService(
      providerId: MobilePlannerProviders.gemini,
      apiKey: 'gemini-test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/v1beta/models');
        expect(request.url.queryParameters['key'], 'gemini-test-key');
        return http.Response(
          '{"models":['
          '{"name":"models/gemini-flash","supportedGenerationMethods":'
          '["generateContent"]},'
          '{"name":"models/text-embedding","supportedGenerationMethods":'
          '["embedContent"]}'
          ']}',
          200,
        );
      }),
    );

    final discovery = await service.discoverModels();

    expect(discovery.isConnected, isTrue);
    expect(discovery.models, ['gemini-flash']);
  });

  test(
    'Groq model discovery uses bearer auth and excludes audio models',
    () async {
      final service = HostedPlannerService(
        providerId: MobilePlannerProviders.groq,
        apiKey: 'groq-test-key',
        client: MockClient((request) async {
          expect(request.url.path, '/openai/v1/models');
          expect(request.headers['authorization'], 'Bearer groq-test-key');
          return http.Response(
            '{"data":['
            '{"id":"llama-3.3-70b-versatile","active":true},'
            '{"id":"whisper-large-v3","active":true},'
            '{"id":"retired-model","active":false}'
            ']}',
            200,
          );
        }),
      );

      final discovery = await service.discoverModels();

      expect(discovery.isConnected, isTrue);
      expect(discovery.models, ['llama-3.3-70b-versatile']);
    },
  );

  test(
    'Gemini planner requests JSON output and returns command text',
    () async {
      final service = HostedPlannerService(
        providerId: MobilePlannerProviders.gemini,
        apiKey: 'gemini-test-key',
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/v1beta/models/gemini-flash:generateContent',
          );
          expect(
            request.body,
            contains('"responseMimeType":"application/json"'),
          );
          return http.Response(
            '{"candidates":[{"content":{"parts":[{"text":'
            '"{\\"kind\\":\\"complete\\",\\"message\\":\\"Done\\"}"}]}}]}',
            200,
          );
        }),
      );

      final output = await service.generatePlannerCommand(
        prompt: 'Return JSON',
        model: 'gemini-flash',
      );

      expect(output, '{"kind":"complete","message":"Done"}');
    },
  );

  test('Groq planner uses JSON mode and returns one command', () async {
    final service = HostedPlannerService(
      providerId: MobilePlannerProviders.groq,
      apiKey: 'groq-test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/openai/v1/chat/completions');
        expect(request.headers['authorization'], 'Bearer groq-test-key');
        expect(request.body, contains('"type":"json_object"'));
        return http.Response(
          '{"choices":[{"message":{"content":'
          '"{\\"kind\\":\\"complete\\",\\"message\\":\\"Done\\"}"}}]}',
          200,
        );
      }),
    );

    final output = await service.generatePlannerCommand(
      prompt: 'Return JSON',
      model: 'llama-3.3-70b-versatile',
    );

    expect(output, '{"kind":"complete","message":"Done"}');
  });

  test('hosted discovery refuses a missing key without network', () async {
    var called = false;
    final service = HostedPlannerService(
      providerId: MobilePlannerProviders.groq,
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    final discovery = await service.discoverModels();

    expect(discovery.isConnected, isFalse);
    expect(discovery.error, contains('API key'));
    expect(called, isFalse);
  });

  test('Gemini network errors redact the API key', () async {
    const secret = 'sensitive-gemini-key';
    final service = HostedPlannerService(
      providerId: MobilePlannerProviders.gemini,
      apiKey: secret,
      client: MockClient((request) async {
        throw http.ClientException(
          'failed request ${request.url}',
          request.url,
        );
      }),
    );

    final discovery = await service.discoverModels();

    expect(discovery.isConnected, isFalse);
    expect(discovery.error, isNot(contains(secret)));
    expect(discovery.error, contains('[redacted]'));
  });
}
