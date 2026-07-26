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
    final voicePrompt = GeminiService.voicePersonalityPrompt;

    expect(
      voicePrompt,
      contains('Beatrice — Beatrice OS\'s conversational voice'),
    );
    expect(voicePrompt, isNot(startsWith(BeatricePersona.chatPrompt)));
    expect(
      voicePrompt,
      contains('Ground every claim in what was actually heard'),
    );
    expect(voicePrompt, contains('specific confirmation before'));
    expect(voicePrompt, contains('Speak in short, interruptible chunks'));
    expect(voicePrompt, contains('interruptible chunks. Direct answer first'));
    expect(voicePrompt, contains('Kore\'s natural conversational range'));
    expect(voicePrompt, contains('yield'));
    expect(voicePrompt, contains('Never manufacture emotion'));
    expect(voicePrompt, contains('Never expose internal model names'));
    expect(voicePrompt, contains('compact brief'));
    expect(
      RegExp(r'\S+').allMatches(BeatricePersona.voicePrompt).length,
      lessThanOrEqualTo(600),
    );
  });

  test('persona preserves verified execution and consent boundaries', () {
    expect(BeatricePersona.chatPrompt, contains('capable human'));
    expect(BeatricePersona.chatPrompt, contains('Not a bot, not a'));
    expect(BeatricePersona.chatPrompt, contains("How can I help you today"));
    expect(BeatricePersona.chatPrompt, contains('Never invent a name'));
    expect(BeatricePersona.chatPrompt, contains('respond to what they'));
    expect(
      BeatricePersona.chatPrompt,
      contains('If you disagree, say so with a reason'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('A genuine "Hmm.", "Maybe.", or "Nah."'),
    );
    expect(BeatricePersona.chatPrompt, contains('Empathy is specific'));
    expect(BeatricePersona.chatPrompt, contains('Never claim to remember'));
    expect(
      BeatricePersona.chatPrompt,
      contains('low-risk reversible actions without ceremony'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Never narrate internal steps'),
    );
  });
}
