# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

BeatriceVoice — an AI voice/chat assistant ("Beatrice", by Beatrice OS) built on Next.js 16 (App Router) with Gemini as the primary model, plus Ollama and Hugging Face Flux as alternative providers. A Flutter port of the same product lives under `flutter/`.

## Commands

```bash
npm install          # install deps
npm run dev          # next dev on :3000, bound to 0.0.0.0 (see dev.js)
npm run build        # next build
npm start            # next start on :3000 (see start.js)
npm run lint         # tsc --noEmit  (this is the typecheck — there is no ESLint config)
```

There is no test runner configured in the Next app. The Flutter project has tests under `flutter/test/` run with `flutter test` (single file: `flutter test test/widget_test.dart`).

## Environment

Copy `.env.example` → `.env.local`. Keys are intentionally exposed to the client (`NEXT_PUBLIC_*`) because **all AI calls run client-side** — there are no Next API routes or server actions. The Gemini client (`src/services/gemini.ts`) is `null` and the service throws "API key not configured" if no key is present. `next.config.mjs` falls back from `NEXT_PUBLIC_*` to the non-prefixed var. Supabase URL/key default to placeholders, so the app runs without Supabase but persistence silently no-ops.

The app integrates with Google AI Studio at runtime via `window.aistudio` (key selection) — guarded behind optional `aistudio?.` checks.

## Architecture

**Single-page client app.** The entire UI is one 2.5k-line client component, `src/app/page.tsx` — chat, voice (Live API), image gen, camera, sidebar, settings, and Supabase auth all live there. `src/app/layout.tsx` is a bare shell. There are no route handlers; everything calls the service modules directly from the browser.

**Service layer (`src/services/`)** — each provider is one module, all client-side:

- `gemini.ts` — chat (streaming + non-streaming), image gen/edit, image analysis, TTS, audio transcription, and the Live API voice session (`connectLive`). **The `models` object at the top is the single source of truth for all Gemini model IDs** — change model strings there, not at call sites. Contains two distinct system prompts: `SYSTEM_PROMPT` (text chat) and `VOICE_PERSONALITY_PROMPT_BODY` (multilingual voice persona for Live API).
- `ollama.ts` — alternative chat via local/hosted Ollama (`OLLAMA_BASE_URL` / `OLLAMA_MODEL`, defaults to `codemax-beta:latest`). Streaming generator.
- `flux.ts` — Hugging Face Flux.1-dev image gen via Inference API; aspect-ratio → dimension mapping is hardcoded here.
- `tools.ts` — Gemini function-calling declarations + `executeTool` dispatcher (calculator, calendar mock). Add new tools to both the `tools` array and the `executeTool` switch.
- `memory.ts` — long-term memory: `extractAndStoreMemories` calls Gemini to pull facts from a conversation, stores them in Supabase `memories`, and `buildMemoryContext` formats them back into the system prompt.
- `profile.ts` / `device.ts` — unauthenticated per-device preferences.

**Two parallel identity models** (the key thing to understand before touching persistence):

- **Authenticated** (`auth.users` from Supabase) → rows in `chats`, `messages`, `memories` are keyed by `user_id` and protected by RLS (`auth.uid() = user_id`).
- **Unauthenticated** → `device_profiles` keyed by a fingerprint-derived `device_id` stored in `localStorage` (`src/services/device.ts`). That table's RLS is intentionally open (`USING (true)`) because there is no auth. Don't key unauthenticated data off `user_id` and don't add auth gates to device-profile flows.

`db.sql` is the authoritative Supabase schema (tables, indexes, RLS policies, the `touch_memory` function). Run it against your Supabase project to provision everything; keep it in sync when you change table shapes.

**Flutter port (`flutter/`)** mirrors the same architecture in Dart: `lib/data/services/*` ↔ `src/services/*`, `lib/data/models/*` ↔ the TS interfaces, `lib/data/repositories/supabase_repository.dart` ↔ `src/lib/supabase.ts`. It's a separate build system (`flutter` SDK, `pubspec.yaml`) — not part of the npm/Next toolchain. The TS app is the source of truth; when changing provider behavior or the schema, consider whether the Dart port needs the same change.

## Conventions

- `tsconfig.json` has `strict: false` — the codebase is not strictly typed; match the surrounding permissiveness rather than introducing strict patterns piecemeal.
- `vite.config.ts` and the `@vitejs/plugin-react` / `tailwindcss/vite` deps are leftover AI Studio scaffolding; the app runs through Next, not Vite. Don't route new work through Vite.
- Tailwind v4 via `@tailwindcss/postcss` (see `postcss.config.mjs`); styles use Tailwind utility classes plus `motion/react` for animation.
- Remote images are allowlisted in `next.config.mjs` (`eburon.ai`, `picsum.photos`) — add hosts there when wiring new image sources.
