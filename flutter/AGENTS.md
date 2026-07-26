# Repository Guidelines

Flutter port of **BeatriceVoice** — Beatrice OS's conversational AI voice/chat assistant. It mirrors the Next.js source of truth (`../src`) in Dart, adding mobile-only capabilities (camera, ML Kit object detection, on-device OCR, MobileUseAgent runtime). The TS app is authoritative for provider behavior and schema; assess Dart parity when those change. `lib/data/services/beatrice_persona.dart` is the single source of truth for Beatrice's system prompts — edit personality there, not in provider services.

## Project Structure & Module Organization

```
flutter/
├── lib/
│   ├── main.dart              # entry point
│   ├── app.dart               # root widget
│   ├── data/
│   │   ├── models/            # chat, message, memory, device_profile
│   │   ├── repositories/      # supabase_repository.dart
│   │   └── services/          # 19 service files (gemini, ollama, flux,
│   │                          #   live_api, audio, memory, mobile_use_agent, …)
│   └── ui/
│       ├── core/              # theme + shared widgets
│       └── features/          # auth, chat, voice, camera, home, sidebar,
│                              #   settings, attachment
├── test/                      # 11 *_test.dart files
├── android/ ios/ macos/ web/  # platform shells
└── pubspec.yaml / analysis_options.yaml
```

## Build, Test, and Development Commands

| Command | Purpose |
| --- | --- |
| `flutter pub get` | Install dependencies from `pubspec.yaml`. |
| `flutter run` | Run on a connected device/emulator (`-d chrome` for web). |
| `flutter build apk \| ios \| macos \| web` | Produce platform release artifacts. |
| `flutter test` | Run all tests under `test/`; single file: `flutter test test/foo_test.dart`. |
| `flutter analyze` | Static analysis via `analysis_options.yaml` (the Dart linter — no separate ESLint step). |
| `dart format .` | Apply Dart formatting before committing. |

## Coding Style & Naming Conventions

- Follow `flutter_lints` (activated in `analysis_options.yaml`); customize rules there, not inline.
- Use `dart format` (2-space indent, 80-col default) before committing.
- Files: `snake_case.dart`. Classes: `PascalCase`. Services end `_service.dart`, models use plain nouns, screens end `_screen.dart`.
- One feature per directory under `ui/features/`; shared widgets under `ui/core/widgets/`.

## Testing Guidelines

- Framework: `flutter_test` (SDK). Tests in `test/` mirror `lib/` paths (e.g. `test/audio_service_test.dart` ↔ `lib/data/services/audio_service.dart`).
- Name files `<unit>_test.dart`; describe the unit under test, not the scenario.
- CI must pass `flutter analyze` **and** `flutter test` together.
- Prefer focused unit tests for service logic (persona, memory, audio, planner, coordinator); reserve widget tests for UI contracts.

## Configuration & Security Tips

- Never commit secrets (Gemini, Ollama, Hugging Face, Supabase). Store them in `flutter_secure_storage` or platform env, not source.
- Supabase schema mirrors the TS app's `../db.sql`. Authenticated rows keyed by `user_id` (RLS-enforced); unauthenticated `device_profiles` keyed by fingerprint-derived `device_id` with open RLS — keep the two models separate.
- UI provider aliases use planet/stone names; model IDs live in service files. When rebrending aliases, update both UI labels and service mappings.

## Commit & Pull Request Guidelines

Follow **Conventional Commits**, matching existing history:

```
feat: add models configuration view for Gemini and Ollama providers
fix: update streaming configuration for Live API
docs: update AGENTS.md with expanded service documentation
refactor: rebrand model provider labels to planet names
```

- Scope optional but encouraged for cross-cutting work (e.g. `feat(flutter):`).
- Subject line lowercase, imperative, ≤72 chars; body explains *why*, not *what*.
- PRs must pass `flutter analyze` + `flutter test`, link the related issue, and call out TS↔Dart parity implications. UI/provider changes should include before/after screenshots or a short screen recording.
