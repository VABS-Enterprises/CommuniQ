# CommuniQ — Project Architecture

This document describes the current architecture of the CommuniQ system — how each component is structured, how they communicate, and how a conversation session flows from end to end.

---

## High-Level Overview

CommuniQ is built as a monorepo with three independent sub-projects that work together:

```
┌─────────────────────────────────────────────────────┐
│                    Flutter Client                    │
│         (Android / iOS / Web / Desktop)              │
│                                                      │
│  - UI and navigation                                 │
│  - Voice recording + amplitude-based VAD             │
│  - Audio playback (chunked)                          │
│  - Session and conversation state management         │
└──────────────┬──────────────────────┬───────────────┘
               │  HTTP / SSE          │  HTTP
               ▼                      ▼
┌──────────────────────┐   ┌─────────────────────────┐
│      AI Server       │   │    General Server        │
│   (Python FastAPI)   │   │    (Node.js / Express)   │
│                      │   │                          │
│  - STT (Whisper)     │   │  - User accounts         │
│  - LLM roleplay      │   │  - Session history       │
│  - TTS synthesis     │   │  - Scenario templates    │
│  - Evaluation        │   │  - Leaderboards          │
└──────────────────────┘   └─────────────────────────┘
         │                          
         ▼                          
┌──────────────────────┐
│    External APIs     │
│                      │
│  - Groq API          │
│    (Whisper STT      │
│     + Llama 3.1 LLM) │
│  - edge-tts (free)   │
│  - Google Cloud TTS  │
│    (optional)        │
└──────────────────────┘
```

---

## Components

### Flutter Client (`client/`)

The user-facing app. Targets Android, iOS, Web, Windows, macOS, and Linux from a single codebase.

**Architecture pattern:** MVC-like with repositories and services

```
lib/
├── views/           # UI screens (home, conversation, settings)
├── controllers/     # State management per screen
├── repository/      # Data access layer (user, conversation, scenario)
├── data/
│   ├── models/      # Core data models (User, Conversation, Scenario, Feedback)
│   └── dto/         # API request/response shapes
├── core/
│   ├── services/    # API, auth, database, audio services
│   ├── theme/       # App-wide colors, typography, spacing
│   ├── constants/   # App-wide constants
│   ├── routes/      # Navigation routes
│   ├── helpers/     # Utility functions
│   └── extensions/  # Dart extension methods
└── common_widgets/  # Reusable UI components
```

**Current status:** Architecture scaffold in place. All feature directories contain placeholder files. No feature logic implemented yet.

---

### AI Server (`ai-server/`)

The AI brain of the app. Built with FastAPI. Handles all speech, language, and evaluation logic.

```
ai-server/
├── main.py          # FastAPI app and endpoint definitions
├── prompts.py       # Generic prompt builders (no hardcoded personas)
├── stt.py           # Speech-to-text via Groq Whisper
├── tts.py           # Text-to-speech with sentence-level streaming
├── evaluator.py     # Evaluation JSON parsing and validation
├── requirements.txt
├── .env             # API keys (never committed)
├── .env.example     # Key template
└── test_pipeline.py # End-to-end test script
```

**Current status:** Active development on the `AI-server` branch. `test_groq.py` (Groq connectivity test) is the only working file so far.

---

### General Server (`server/`)

Backend for non-AI concerns: user authentication, session persistence, scenario template storage, and progress tracking. Implemented as a Node.js / Express REST API, authenticated via Bearer tokens (Firebase ID tokens), backed by Firestore through the firebase-admin SDK.

**Current status:** Implemented and deployed. Exposes session, user, and scenario endpoints and proxies conversation turns to the AI server.

---

## AI Server — Detailed Architecture

### The Three Endpoints

```
POST /conversation   ← primary endpoint for live conversation turns
POST /evaluate       ← triggered at session end, returns performance scores
POST /tts            ← utility endpoint for standalone text-to-speech
```

### How Prompts Work

The AI server has no hardcoded personas. Instead, `prompts.py` exposes two builder functions:

- `build_system_prompt(scenario_prompt, agent_description, agent_voice, level)` — assembles the LLM system prompt from variables sent by the Flutter client. Universal behavioral rules are baked in on the server side; the scenario-specific content comes from the frontend template.
- `build_evaluator_prompt(scenario_prompt, agent_description, level)` — builds the evaluation instruction including the strict JSON output schema.

This means the Flutter client fully owns scenario templates. New scenarios can be added or existing ones edited without any server changes.

### Scenario Templates (Frontend-owned)

Each template the Flutter client sends contains:

| Field | Example |
|---|---|
| `scenario_prompt` | "You are conducting a behavioral interview for a software engineering role. Ask STAR-format questions..." |
| `agent_description` | "Senior HR manager at a mid-size Indian tech company" |
| `agent_voice` | "formal, measured, no filler responses" |
| `level` | `beginner` / `intermediate` / `advanced` |

---

## Conversation Session Flow

This is a complete walkthrough of one conversation turn, from when the user stops speaking to when they hear the AI respond.

```
┌──────────────────────────────────────────────────────────────────┐
│  Flutter Client                                                   │
│                                                                   │
│  1. Mic open — amplitude VAD monitors in real time               │
│  2. User finishes speaking — silence for ~1.2s detected          │
│  3. Recording stops automatically                                 │
│  4. Flutter sends POST /conversation (multipart):                │
│       audio file + messages history + scenario variables         │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  AI Server — /conversation handler                                │
│                                                                   │
│  Step 1: STT                                                      │
│    stt.py → Groq Whisper Large V3                                │
│    Audio bytes → transcript text (~0.5–0.8s)                     │
│    → SSE event: { type: "transcript", text: "..." }              │
│                                                                   │
│  Step 2: Build system prompt                                      │
│    prompts.py → build_system_prompt(variables from request)      │
│    Combines scenario content + universal behavioral rules        │
│                                                                   │
│  Step 3: LLM stream                                               │
│    Groq Llama 3.1 8B Instant                                     │
│    Streams tokens as they arrive                                  │
│    → SSE event per token: { type: "text_chunk", text: "word" }  │
│                                                                   │
│  Step 4: Sentence-level TTS (overlapped)                         │
│    tts.py detects sentence boundary (. ! ? or long clause ,)    │
│    → Synthesizes that sentence with edge-tts immediately         │
│    → SSE event: { type: "audio_chunk", data: "base64_mp3" }     │
│    While Flutter plays chunk N, chunk N+1 is already synthesizing│
│                                                                   │
│  Step 5: Done                                                     │
│    → SSE event: { type: "done" }                                 │
└───────────────────────────┬──────────────────────────────────────┘
                            │  SSE stream
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Flutter Client (receiving SSE events)                           │
│                                                                   │
│  transcript event  → show user's words in conversation UI        │
│  text_chunk event  → append tokens to AI response bubble        │
│  audio_chunk event → decode base64, queue in audio player       │
│                      (plays immediately — no waiting for full    │
│                       response before audio starts)              │
│  done event        → re-open mic for next turn                   │
└──────────────────────────────────────────────────────────────────┘
```

**Latency to first audio: ~1.2–1.8 seconds** after the user stops speaking.

---

## Session Evaluation Flow

Evaluation is triggered automatically when the user ends a session. Flutter sends the full conversation transcript plus the same scenario context used during the session.

```
Flutter (session end)
  │
  └─▶ POST /evaluate
        transcript + scenario_prompt + agent_description + level
        │
        ▼
        prompts.py → build_evaluator_prompt()
        │
        ▼
        Groq Llama 3.1 8B (non-streaming)
        │
        ▼
        evaluator.py → parse_evaluation()
          Validates JSON matches exact schema:
          {
            scores: { clarity, fluency, confidence, vocabulary, grammar }
            filler_words: [...],
            filler_count: int,
            strengths: [2 items],
            improvements: [2 items],
            recommended_next: "scenario_level_number"
          }
        │
        ▼
        JSONResponse → Flutter renders evaluation screen
```

---

## TTS Engine

The AI server uses **edge-tts** — free, no account or billing required.

| Engine | Voice | Cost | Latency per sentence |
|---|---|---|---|
| edge-tts | `en-IN-NeerjaNeural` (Indian English, female) | Free | ~300–400ms |

This latency is fast enough for the sentence-overlap streaming to feel seamless.

---

## Interrupt Handling

While the AI is speaking, a visible "Interrupt" button is shown in the Flutter UI. Tapping it:
1. Stops the audio player immediately
2. Opens the mic for the next user turn

The server does not need to be notified of an interrupt — the current SSE connection is simply abandoned by the client, and a new `/conversation` request is made on the next turn.

---

## External API Dependencies

| Service | Purpose | Cost | Required |
|---|---|---|---|
| Groq API | LLM (Llama 3.1 8B) + STT (Whisper Large V3) | Free tier | Yes |
| edge-tts | Text-to-speech (Indian English neural voice) | Free, no account | No (auto-used) |
| ngrok | Expose local server to physical devices | Free tier | No (dev only) |

---

## Data Flow Summary

```
User speaks
  → Flutter VAD detects silence
  → Audio + context sent to /conversation
  → Groq Whisper transcribes
  → Groq LLM generates response (streamed)
  → edge-tts synthesizes sentence by sentence
  → Flutter receives audio chunks via SSE, plays in sequence
  → User hears AI response (~1.5s after stopping)
  → Cycle repeats until session ends
  → Flutter sends transcript to /evaluate
  → Evaluation JSON returned and displayed
```

---

## Current Development Status

| Component | Status |
|---|---|
| Flutter client scaffold | Done — placeholder architecture |
| Flutter features | Not started |
| AI server — Groq connectivity | Done (test_groq.py working) |
| AI server — full implementation | In progress (AI-server branch) |
| General server | Implemented and deployed (Bearer-auth REST API over Firestore) |
