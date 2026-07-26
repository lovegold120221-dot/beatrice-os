# AGENTS.md

BeatriceVoice — an AI voice/chat assistant ("Beatrice", by Beatrice OS) built on Next.js 16 (App Router) with Gemini as the primary model, plus Ollama and Hugging Face Flux as alternative providers. A Flutter port of the same product lives under `flutter/`.

## Commands

```bash
npm install          # install deps
npm run dev          # next dev on :3000, bound to 0.0.0.0 (see dev.js)
npm run build        # next build
npm start            # next start on :3000 (see start.js)
npm run lint         # tsc --noEmit  (this is the typecheck — there is no ESLint config)
```

No test runner in the Next app. Flutter: `flutter test` (11 test files under `flutter/test/`), `flutter analyze` (Dart linting).

## Environment

Copy `.env.example` → `.env.local`. Keys are `NEXT_PUBLIC_*` because **all AI calls run client-side** — there are no Next server actions and only one API route (`api/ollama/models`) that proxies Ollama's `/api/tags` to avoid CORS. `next.config.mjs` falls back from `NEXT_PUBLIC_*` to the non-prefixed var. Supabase defaults to placeholders — app runs without it but persistence silently no-ops. The app integrates with Google AI Studio at runtime via `window.aistudio` (key selection) — guarded behind optional `aistudio?.` checks.

Required env vars (see `.env.example`):

- `GEMINI_API_KEY` / `NEXT_PUBLIC_GEMINI_API_KEY` — required for all Gemini features
- `OLLAMA_BASE_URL` — defaults to `http://localhost:11434`
- `HF_TOKEN` / `NEXT_PUBLIC_HF_TOKEN` — for Flux image generation
- `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` — optional (persistence)

## Architecture

**Single-page client app.** All UI lives in `src/app/page.tsx` (~100k lines, client component). `src/app/layout.tsx` is a bare shell. No route handlers or server components.

**Service layer (`src/services/`)** — all client-side:

- `gemini.ts` — chat (streaming + non-streaming), image gen/edit, image analysis, TTS, audio transcription, Live API voice session (`connectLive`). **`models` object at the top is the single source of truth for all Gemini model IDs.** Live API enables: barge-in/interruption, low first-audio latency, speech-specific response generation, prosody/emotion controls, streaming sentence chunking, echo cancellation + VAD, stable multilingual voice, context/task memory, natural fillers/pauses, continuous evaluation via real conversations.
- `ollama.ts` — alternative chat via local/hosted Ollama.
- `flux.ts` — Hugging Face Flux.1-dev image gen; aspect-ratio → dimension mapping hardcoded.
- `tools.ts` — Gemini function-calling declarations + `executeTool` dispatcher. Add new tools to both the `tools` array and the `switch`.
- `memory.ts` — long-term memory: `extractAndStoreMemories` → Supabase `memories`.
- `profile.ts` / `device.ts` — unauthenticated per-device preferences.
- **`beatricePersona.ts`** — single source of truth for both system prompts (`BEATRICE_CHAT_PROMPT` and `BEATRICE_VOICE_PROMPT`). Both `gemini.ts` and `ollama.ts` import from here. Change Beatrice's personality here, not in individual service files.

**Two parallel identity models:**

- **Authenticated** (`auth.users` from Supabase) → `chats`, `messages`, `memories` keyed by `user_id`, protected by RLS (`auth.uid() = user_id`).
- **Unauthenticated** → `device_profiles` keyed by a fingerprint-derived `device_id` in `localStorage` (`src/services/device.ts`). RLS is open (`USING (true)`) — no auth. Don't key unauthenticated data off `user_id`.

`db.sql` is the authoritative Supabase schema (tables, indexes, RLS policies, `touch_memory` function). Keep in sync when changing table shapes.

**Flutter port (`flutter/`)** mirrors the architecture but is not a strict 1:1 copy. The Dart port has 19 service files (vs 8 TS services) with additional capabilities: audio processing, live API, mobile task coordination, web lookup, local OCR, mobile use agent runtime, and more. It's a separate build system (`flutter` SDK, `pubspec.yaml`) — not part of the npm/Next toolchain. The TS app is the source of truth; when changing provider behavior or schema, assess whether the Dart port needs the same change.

## Voice Quality Targets

Beatrice's voice behavior targets these benchmarks (via Gemini Live API):

**Response latency** — First audio chunk 300–800 ms; avoid consistent 2–5s silence. Streaming STT → LLM → TTS pipeline; agent can start speaking before full response is assembled.

**Natural prosody** — Pitch, rhythm, stress, and melody vary by intent: questions rise, explanations are steady, warnings drop pitch, jokes lighten, emotional responses match tone. TTS must convey intent, not just text.

**Realistic pauses & breathing** — Short pauses after clauses, longer before key points, brief hesitation before answers, occasional subtle breaths. Avoid over-engineered fillers/breathing that feel artificial.

**Turn-taking & barge-in** — Agent stops TTS immediately when user interrupts (VAD + echo cancellation). No talking over the user.

**Emotion matching** — Voice matches context: softer/slower for bad news, energetic for good news, calm/confident for technical content, controlled for angry users, patient for confused users. Emotion carries through synthesis, not just text.

**Conversational wording** — Output text written for speech, not reading. "Okay, done" not "Your request has been successfully completed." "Sige, bubuksan ko na" not "I am now initiating the application."

**Short semantic chunks** — LLM emits complete phrases/clauses; each chunk sent to TTS separately. Avoids mid-thought cuts and unnatural long-sentence pacing.

**Voice consistency** — Stable speaker identity, pitch, accent, rate, loudness, emotional baseline across turns and languages (Tagalog, English, Dutch, French share one voice identity).

**Context awareness & memory** — Remembers topic, prior instructions, user preferences, names/pronouns, task status, what failed/succeeded. No repeated questions.

**Audio pipeline quality** — VAD, echo cancellation, noise suppression, AGC, mic calibration, TTS ducking, speaker-to-mic echo prevention, clean sample-rate conversion. Prevents self-talk loops and feedback.

## Conventions

- `tsconfig.json` has `strict: false` — match the surrounding permissiveness.
- `vite.config.ts` and `@vitejs/plugin-react` / `tailwindcss/vite` are leftover AI Studio scaffolding; the app runs through Next, not Vite.
- Tailwind v4 via `@tailwindcss/postcss` (see `postcss.config.mjs`); styles use Tailwind utility classes plus `motion/react` for animation.
- Remote images are allowlisted in `next.config.mjs` (`eburon.ai`, `picsum.photos`).
- `metadata.json` declares `camera` and `microphone` frame permissions.
- `docs/HOW_TO_TALK_TO_THIS_USER.md` is a communication-preference blueprint for Beatrice (the product's end-user personality), not for the coding agent.
