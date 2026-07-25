import 'package:beatrice/data/services/live_api_service.dart';
import 'package:beatrice/data/services/mobile_planner_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemini Live declares one bounded MobileUseAgent handoff tool', () {
    final declaration = LiveApiService.mobileTaskToolDeclaration;
    final parameters = declaration['parameters'] as Map<String, dynamic>;

    expect(declaration['name'], 'dispatch_mobile_task');
    expect(parameters['required'], [
      'task',
      'intentType',
      'essentialDetailsComplete',
    ]);
    final properties = parameters['properties'] as Map<String, dynamic>;
    expect(properties.keys, containsAll(['task', 'intentType']));
    expect(properties['essentialDetailsComplete'], isA<Map>());
  });

  test('Live tool calls decode both API casing variants', () {
    final camel = LiveApiService.decodeToolCalls({
      'toolCall': {
        'functionCalls': [
          {
            'id': 'call-1',
            'name': 'dispatch_mobile_task',
            'args': {
              'task': 'Open YouTube',
              'intentType': 'PHONE_TASK',
              'essentialDetailsComplete': true,
            },
          },
        ],
      },
    });
    final snake = LiveApiService.decodeToolCalls({
      'tool_call': {
        'function_calls': [
          {
            'id': 'call-2',
            'name': 'dispatch_mobile_task',
            'arguments': {'task': 'Open Settings'},
          },
        ],
      },
    });

    expect(camel.single.arguments['task'], 'Open YouTube');
    expect(snake.single.arguments['task'], 'Open Settings');
  });

  test('Live tool responses preserve the matching function call id', () {
    final payload = LiveApiService.buildToolResponsePayload(
      id: 'call-1',
      name: 'dispatch_mobile_task',
      response: const {'status': 'delivered'},
    );
    final toolResponse = payload['toolResponse'] as Map<String, dynamic>;
    final responses = toolResponse['functionResponses'] as List<dynamic>;

    expect(responses.single['id'], 'call-1');
    expect(responses.single['name'], 'dispatch_mobile_task');
  });

  test(
    'provider menu is unique and marks only working adapters integrated',
    () {
      final ids = MobilePlannerProviders.options
          .map((provider) => provider.id)
          .toList();

      expect(ids.toSet().length, ids.length);
      expect(
        MobilePlannerProviders.byId(
          MobilePlannerProviders.ollamaLocal,
        ).isIntegrated,
        isTrue,
      );
      expect(
        MobilePlannerProviders.byId(
          MobilePlannerProviders.ollamaCloud,
        ).isIntegrated,
        isTrue,
      );
      expect(MobilePlannerProviders.byId('gemini').isIntegrated, isFalse);
      expect(
        MobilePlannerProviders.byId('opencode-zen-free').label,
        contains('Zen'),
      );
    },
  );
}
