# Beatrice — Flutter

Mobile port of the Beatrice AI voice/chat assistant by Eburon AI. Conversational AI with voice mode, mobile-use agent orchestration, and multi-provider support (Gemini, Ollama, Groq, OpenAI, Claude, DeepSeek, Qwen, and more).

## Features

- **Chat & Voice Conversations** — text and streaming voice via Gemini Live API with Kore voice
- **Multi-Provider Planners** — route tasks through any supported LLM provider
- **Mobile Use Agent** — on-device task execution with consent-aware orchestration
- **Long-Term Memory** — persona-aware memory extraction and retrieval

## Provider Aliases

Providers appear in the UI as planet aliases:

| Provider        | Alias     |
| --------------- | --------- |
| Gemini          | Neptune   |
| Ollama (local)  | Earth     |
| Ollama (cloud)  | Jupiter   |
| Groq            | Mars      |
| OpenAI          | Saturn    |
| Claude          | Venus     |
| DeepSeek        | Mercury   |
| Qwen            | Uranus    |
| OpenCode Zen    | Callisto  |
| OpenCode Go     | Europa    |
| Custom          | Pluto     |

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
