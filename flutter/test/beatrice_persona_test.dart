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

    expect(voicePrompt, contains('# BEATRICE LIVE — LOW-LATENCY CORE'));
    expect(voicePrompt, isNot(startsWith(BeatricePersona.chatPrompt)));
    expect(
      voicePrompt,
      contains('Ground every fact, memory, quotation, current event'),
    );
    expect(voicePrompt, contains('specific confirmation before send'));
    expect(voicePrompt, contains('Do not enter an agreement loop'));
    expect(
      voicePrompt,
      contains('Respect does not require automatic agreement'),
    );
    expect(voicePrompt, contains('restart briefly in varied'));
    expect(voicePrompt, contains('never in adjacent turns'));
    expect(
      voicePrompt,
      contains('attentive secretary speaking with the Boss or user'),
    );
    expect(
      voicePrompt,
      contains('A tiny honest response may be the whole turn'),
    );
    expect(voicePrompt, contains('Stay inside the subject'));
    expect(voicePrompt, contains('never disagree merely to'));
    expect(
      voicePrompt,
      contains('empty contradiction, paradox, or logic loop'),
    );
    expect(voicePrompt, contains('may invent an image, never a fact'));
    expect(voicePrompt, contains('claim the user supplied its premise'));
    expect(voicePrompt, contains('finish only the short sentence'));
    expect(voicePrompt, contains('If their meaning is clear, answer it'));
    expect(voicePrompt, contains('override graceful completion'));
    expect(voicePrompt, contains('yield as quickly as possible'));
    expect(voicePrompt, contains('configured Kore native voice'));
    expect(voicePrompt, contains('restrained almost-laugh'));
    expect(voicePrompt, contains('brief hesitation'));
    expect(
      voicePrompt,
      contains('Convey expression through native-audio prosody'),
    );
    expect(voicePrompt, contains('Never say or display audio'));
    expect(voicePrompt, contains('Keep fillers sparse'));
    expect(voicePrompt, contains('Make one fast check before speaking'));
    expect(voicePrompt, isNot(contains('silently rehearse')));
    expect(voicePrompt, contains('Never open with a generic'));
    expect(voicePrompt, contains('scripted support closer'));
    expect(voicePrompt, contains('breathy chuckle'));
    expect(voicePrompt, contains('short near-whisper'));
    expect(voicePrompt, contains('Oh, really?'));
    expect(voicePrompt, contains('Never claim a physical home'));
    expect(voicePrompt, contains('one compact'));
    expect(voicePrompt, contains('actionable brief'));
    expect(
      RegExp(r'\S+').allMatches(BeatricePersona.voicePrompt).length,
      lessThanOrEqualTo(1100),
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
      contains('Respect does not require automatic agreement'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('A tiny honest response can be the whole turn'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('never disagree merely to create friction'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Respectful disagreement is allowed'),
    );
    expect(
      BeatricePersona.chatPrompt,
      contains('Never attribute the premise to the user'),
    );
    expect(BeatricePersona.chatPrompt, contains("Wait, who's Leanne?"));
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
