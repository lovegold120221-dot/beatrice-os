import 'dart:typed_data';

import 'package:beatrice/data/services/gemini_service.dart';
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
    expect(declaration['description'], contains('Never guess'));
  });

  test('Live handoff behaves like a grounded conversational secretary', () {
    final instruction = LiveApiService.secretaryHandoffInstruction;

    expect(instruction, contains('Never predict, assume, autocomplete'));
    expect(instruction, contains('repeat that word or phrase'));
    expect(
      instruction,
      contains('Never make the user repeat the whole request'),
    );
    expect(
      instruction,
      contains('quietly preparing work while still listening'),
    );
    expect(instruction, contains('Call dispatch_mobile_task exactly once'));
    expect(
      instruction,
      contains('does not mean the task started or completed'),
    );
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

  test('compatible native-audio setup enables affective dialogue', () {
    const model = 'gemini-2.5-flash-native-audio-preview';
    expect(LiveApiService.supportsAffectiveDialog(model), isTrue);
    expect(
      LiveApiService.supportsAffectiveDialog('gemini-3.1-flash-live-preview'),
      isFalse,
    );

    final payload = LiveApiService.buildSetupPayload(
      model,
      'Beatrice prompt',
      LiveApiService.koreVoiceName,
      16000,
      24000,
      enableAffectiveDialog: true,
    );
    final setup = payload['setup'] as Map<String, dynamic>;
    final generation = setup['generationConfig'] as Map<String, dynamic>;
    expect(generation['enableAffectiveDialog'], isTrue);
    final thinking = generation['thinkingConfig'] as Map<String, dynamic>;
    expect(thinking['thinkingBudget'], 0);
    expect(thinking['includeThoughts'], isFalse);
    final speech = generation['speechConfig'] as Map<String, dynamic>;
    final voiceConfig = speech['voiceConfig'] as Map<String, dynamic>;
    final prebuilt = voiceConfig['prebuiltVoiceConfig'] as Map<String, dynamic>;
    expect(prebuilt['voiceName'], 'Kore');
    expect(GeminiService.speechVoiceName, 'Kore');
    final realtime = setup['realtimeInputConfig'] as Map<String, dynamic>;
    expect(
      realtime['activityHandling'],
      LiveApiService.conversationalActivityHandling,
    );
    expect(realtime['activityHandling'], 'NO_INTERRUPTION');
  });

  test('Live audio uses current realtime fields and flushes stream end', () {
    final audio = LiveApiService.buildRealtimeAudioPayload(
      Uint8List.fromList([1, 2, 3, 4]),
    );
    final realtime = audio['realtimeInput'] as Map<String, dynamic>;

    expect(realtime['audio'], isA<Map<String, dynamic>>());
    expect(realtime, isNot(contains('mediaChunks')));
    expect(LiveApiService.buildAudioStreamEndPayload(), {
      'realtimeInput': {'audioStreamEnd': true},
    });
  });

  test('Live voice contract uses a sentence-boundary handoff', () {
    const prompt = GeminiService.voicePersonalityPrompt;

    expect(prompt, contains('finish your current short sentence'));
    expect(prompt, contains('yield'));
    expect(prompt, contains('interruptible chunks'));
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
      expect(
        MobilePlannerProviders.byId(MobilePlannerProviders.gemini).isIntegrated,
        isTrue,
      );
      expect(
        MobilePlannerProviders.byId(MobilePlannerProviders.groq).isIntegrated,
        isTrue,
      );
      expect(
        MobilePlannerProviders.byId('gemini').label,
        contains('Eburon'),
      );
    },
  );
}
