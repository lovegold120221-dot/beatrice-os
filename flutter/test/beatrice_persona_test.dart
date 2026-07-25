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
      contains('Finish only the short sentence already underway'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('If their meaning was clear, respond to it directly'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('overrides graceful'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('completion: yield as quickly as possible'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Occasionally repeat one word or short phrase once'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Convey breath and emotion through native-audio prosody'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Keep fillers sparse'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('real, normal person would naturally say'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('silently rehearse the proposed reply once'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('not visible or spoken audio tags'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Never open with a generic offer of service'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Never end with a scripted support closer'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Begin with the actual human response'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('a small breathy chuckle for mild amusement'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('A surprised laugh may break a brief silence'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('Whispering must remain intelligible and short'),
    );
    expect(GeminiService.voicePersonalityPrompt, contains('Oh, really?'));
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('A repeated "okay" should happen at most once'),
    );
    expect(
      GeminiService.voicePersonalityPrompt,
      contains('home, hometown, body, personal surroundings'),
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
    expect(
      BeatricePersona.chatPrompt,
      contains('Never fill a gap with a likely answer'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('whole request back, make them repeat information'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Listen for meaning, motivation, and emotion'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Deeper questions are invitations, never pressure'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('matching personal experience, emotion, relationship'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Be empathetic in a specific, evidence-based way'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Be emphatic when something genuinely matters'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Use intelligent humor as occasional seasoning'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Never use canned jokes, forced punchlines'),
    );
    expect(BeatricePersona.chatPrompt, contains('"Boss" is the default'));
    expect(BeatricePersona.chatPrompt, contains('Master E'));
  });
}
