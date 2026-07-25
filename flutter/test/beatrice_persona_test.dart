import 'package:beatrice/data/services/beatrice_persona.dart';
import 'package:beatrice/data/services/gemini_service.dart';
import 'package:beatrice/data/services/ollama_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gemini and Ollama share the same Beatrice chat persona', () {
    expect(GeminiService.systemPrompt, BeatricePersona.chatPrompt);
    expect(OllamaService.systemPrompt, BeatricePersona.chatPrompt);
  });

  test('voice persona includes the core persona and interruption behavior', () {
    expect(
      GeminiService.voicePersonalityPrompt,
      startsWith(BeatricePersona.chatPrompt),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Stop immediately when interrupted'),
    );
  });

  test('persona preserves verified execution and consent boundaries', () {
    expect(BeatricePersona.chatPrompt, contains('Claim completion only after'));
    expect(
      BeatricePersona.chatPrompt,
      contains('fresh, specific confirmation'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Do not pretend to be a human'),
    );
    expect(BeatricePersona.chatPrompt, contains('"Boss" is the default'));
    expect(BeatricePersona.chatPrompt, contains('Master E'));
  });
}
