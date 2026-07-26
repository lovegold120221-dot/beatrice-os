# Beatrice — Flutter

Mobile port of the Beatrice AI voice/chat assistant by Eburon AI. Conversational AI with voice mode, mobile-use agent orchestration, and multi-provider support (Gemini, Ollama, Groq, OpenAI, Claude, DeepSeek, Qwen, and more).

## Features

- **Chat & Voice Conversations** — text and streaming voice via Gemini Live API with Kore voice
- **Multi-Provider Planners** — route tasks through any supported LLM provider
- **Mobile Use Agent** — on-device task execution with consent-aware orchestration
- **Long-Term Memory** — persona-aware memory extraction and retrieval

## Provider Aliases

Providers appear in the UI as planet aliases:

| Provider        | Alias        |
| --------------- | ------------ |
| Gemini          | Eburon       |
| Groq            | Eburon-OS    |
| Ollama (cloud)  | Eburon-cloud |
| Ollama (local)  | Eburon-local |

## Voice — Star Names

Live voice conversations use Gemini prebuilt voices aliased as star names:

| Voice API | Star alias |
| --------- | ---------- |
| Kore      | Polaris    |
| Puck      | Vega       |
| Aoede     | Sirius     |
| Charon    | Rigel      |
| Fenrir    | Betelgeuse |
| Leda      | Aldebaran  |
| Orus      | Altair     |

## Getting Started

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install)

```bash
flutter pub get
flutter run
```

Build a release APK:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

## Test

```bash
flutter test          # 62+ tests
flutter analyze       # lint check
```
