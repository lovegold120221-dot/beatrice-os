# Repository Guidelines

This is the **Flutter port of BeatriceVoice** — Beatrice OS's conversational AI voice/chat assistant. It mirrors the Next.js source of truth (`../src`) in Dart, adding mobile-only capabilities (camera, ML Kit object detection, on-device OCR, MobileUseAgent runtime). The TS app remains authoritative for provider behavior and schema changes; assess Dart parity when those change.

## Project Structure & Module Organization

```
flutter/
├── lib/
│   ├── main.dart               # entry point
│   ├── app.dart                # root widget
│   ├── data/
│   │   ├── models/             # chat, message, memory, device_profile
│   │   ├── repositories/       # supabase_repository.dart
│   │   └── services/           # 19 service files (gemini, ollama, flux,
│   │                           #   live_api, audio, memory, beatrice_persona,
│   │                           #   mobile_use_agent_runtime, local_ocr, …)
│   └── ui/
│       ├── core/               # theme, shared widgets (code_block)
│       └── features/           # auth, chat, voice, camera, home, sidebar,
│                               #   settings, attachment
├── test/                       # 11 *_test.dart files (flutter_test SDK)
├── android/ ios/ macos/ web/   # platform shells
├── pubspec.yaml                # deps & launcher icons
├── analysis_options.yaml       # flutter_lints rules
└── logo.png                    # launcher icon source
```

`lib/data/services/beatrice_persona.dart` is the single source of truth for Beatrice's system prompts — edit personality there, not in provider services.

## Build, Test, and Development Commands

| Command | Purpose |
| --- | --- |
| `flutter pub get` | Install dependencies from `pubspec.yaml`. |
| `flutter run` | Run the app on a connected device/emulator. |
| `flutter run -d chrome` | Run the web build. |
| `flutter build apk` / `ios` / `macos` / `web` | Produce platform release artifacts. |
| `flutter test` | Run all tests under `test/`. |
| `flutter test test/foo_test.dart` | Run a single test file. |
| `flutter analyze` | Static analysis via `analysis_options.yaml` (the Dart linter — there is no separate ESLint step). |
| `dart format .` | Apply Dart formatting. |

## Coding Style & Naming Conventions

- Follow `flutter_lints` (activated in `analysis_options.yaml`); keep rules customized there, not suppressed inline unless necessary.
- Use `dart format` (2-space indent, 80-col default) before committing.
- Files: `snake_case.dart`. Classes: `PascalCase`. Service files end in `_service.dart` (`gemini_service.dart`), models in plain nouns (`message.dart`), screens in `_screen.dart`.
- One feature per directory under `ui/features/`; shared widgets under `ui/core/widgets/`.

## Testing Guidelines

- Framework: `flutter_test` (SDK). Tests live in `test/` mirroring `lib/` paths (`test/audio_service_test.dart` ↔ `lib/data/services/audio_service.dart`).
- Name test files `<unit>_test.dart`. Describe the unit under test, not the scenario.
- Run the full suite with `flutter test`; CI must pass `flutter analyze` and `flutter test` together.
- Cover service-layer logic (persona, memory, audio, planner, coordinator) with focused unit tests; reserve widget tests (`widget_test.dart`, `composer_voice_ui_test.dart`) for UI contracts.

## Configuration & Security Tips

- Secrets (Gemini, Ollama, Hugging Face, Supabase) are loaded at runtime — never commit keys. Keep them in `flutter_secure_storage` or platform env, not in source.
- Supabase schema mirrors the TS app's `../db.sql`. Keep RLS policies in sync when table shapes change: authenticated rows keyed by `user_id` (RLS-enforced); unauthenticated `device_profiles` keyed by fingerprint-derived `device_id` with open RLS — do not mix the two models.
- Provider aliases in the UI use planet/stone names; the underlying model IDs live in the service files. When rebrending aliases, update both the UI labels and the service mapping.

## Commit & Pull Request Guidelines

Follow **Conventional Commits**, matching the existing history:

```
feat: add models configuration view for Gemini and Ollama providers
fix: update streaming configuration for Live API
docs: update AGENTS.md with expanded service documentation
chore: update build artifacts and add architecture documentation
refactor: rebrand model provider labels to planet names
```

- Scope optional but encouraged for cross-cutting changes (e.g. `feat(flutter):`).
- Subject line lowercase, imperative, ≤72 chars; body explains *why*, not *what*.
- PRs must: pass `flutter analyze` + `flutter test`, link the related issue, and call out any TS↔Dart parity implications. UI/provider changes should include before/after screenshots or a short screen recording.
