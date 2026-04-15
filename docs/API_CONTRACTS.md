# CommuniQ API contracts (Node ↔ Flutter ↔ FastAPI)

All Flutter traffic goes to the **Node** server (authenticated). Node calls **FastAPI** (`FASTAPI_URL`) for AI work.

## Session lifecycle (Node)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/sessions/start` | Bearer | Create session; returns `{ sessionId }`. |
| POST | `/sessions/opening` | Bearer | **Colab parity:** first AI line + MP3 (base64), no user audio. Persists one AI turn in Firestore. Once per session. |
| POST | `/sessions/turn` | Bearer | Multipart: `audioFile`, `sessionId`, `conversationHistory` (JSON array of `{role, transcript}`). Returns `{ userTranscript, aiReply, aiAudioBase64, turnCount }`. |
| POST | `/sessions/end` | Bearer | Body `{ sessionId }`. Runs evaluation on full transcript, completes session, returns report + XP. |
| POST | `/sessions/abandon` | Bearer | Body `{ sessionId }`. |

### `conversationHistory` (turn)

Mirrors Firestore order: optional leading **AI** opening, then alternating **user** / **ai** pairs. Node forwards the same array to FastAPI `/session/turn` for LLM context.

### Turn limits

Maximum **50 user** turns per session. The AI-only opening does not count toward that cap.

## FastAPI session routes (Node → FastAPI)

| Method | FastAPI path | Content-Type | Body / form | Response |
|--------|----------------|--------------|-------------|----------|
| POST | `/session/opening` | `application/json` | `{ sessionId, systemPrompt }` | `{ aiReply, aiAudioBase64 }` |
| POST | `/session/turn` | `multipart/form-data` | `audioFile`, `sessionId`, `conversationHistory`, `systemPrompt` | `{ userTranscript, aiReply, aiAudioBase64 }` |
| POST | `/session/evaluate` | `application/json` | `{ sessionId, fullTranscript, scenarioType }` | `{ scores, fillerWordCount, fillerWords, strengths, improvements, recommendedNextType }` |

Audio is **base64-encoded MP3** in JSON responses.

## Evaluation transcript

Node builds `fullTranscript` / stored `rawTranscript` as:

```text
User: …
AI: …
```

including the **opening AI** line when the session used `/sessions/opening`.

## Backend switches (FastAPI env)

| Variable | Default | Meaning |
|----------|---------|---------|
| `ASR_BACKEND` | `groq` | `groq` → Groq Whisper via `app/services/stt.py`. `local` → reserved (e.g. faster-whisper); raises until implemented. |
| `LLM_BACKEND` | `groq` | `groq` → Groq chat completions. `local` → reserved (HF Llama, etc.). |
| `TTS_BACKEND` | `edge` | `edge` → Edge TTS. `local` → reserved (Piper / XTTS / OmniVoice-class). |

Implementations live in `app/services/asr_facade.py`, `llm_facade.py`, `tts_facade.py`.
