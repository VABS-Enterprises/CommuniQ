# CommuniQ AI Server

The AI brain of the CommuniQ app. A FastAPI server that handles speech-to-text, LLM roleplay, text-to-speech, and session evaluation.

## Folder Structure

```
ai-server/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI app — all endpoints
│   ├── prompts.py       # Generic prompt builders (no hardcoded personas)
│   ├── stt.py           # Groq Whisper Large V3 wrapper
│   ├── tts.py           # Sentence-level streaming TTS (edge-tts / Google Cloud)
│   └── evaluator.py     # Evaluation JSON parsing and validation
├── tests/
│   ├── test_pipeline.py # End-to-end test for all API endpoints
│   └── test_groq.py     # Groq connectivity smoke test
├── venv/                # Python virtual environment (git-ignored)
├── .env                 # API keys and config (git-ignored)
├── .env.example         # Key template — copy this to .env
├── requirements.txt     # Pinned Python dependencies
└── README.md
```

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/conversation` | Full turn: STT → LLM → TTS, streamed via SSE |
| POST | `/evaluate` | Evaluate a completed session transcript |
| POST | `/tts` | Synthesize text to MP3 audio |
| GET | `/health` | Server health check |

## Quick Start

```bash
# 1. Activate virtual environment
venv\Scripts\activate          # Windows
source venv/bin/activate       # macOS / Linux

# 2. Install dependencies
pip install -r requirements.txt

# 3. Set up environment variables
cp .env.example .env
# Edit .env and add your GROQ_API_KEY

# 4. Start the server
uvicorn app.main:app --reload --port 8000

# 5. Run tests (server must be running)
python tests/test_pipeline.py
```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GROQ_API_KEY` | If any backend is `groq` | Groq STT/LLM — console.groq.com |
| `LLM_BACKEND` | No | Default `groq`. Use `openai_compat` for Together / OpenRouter / hosted chat APIs. |
| `OPENAI_COMPAT_BASE_URL` | If `LLM_BACKEND` or `EVAL_LLM_BACKEND` is `openai_compat` | API root (e.g. `https://api.openai.com` or `https://api.together.xyz/v1`) |
| `OPENAI_COMPAT_API_KEY` | Same | Bearer token for that API |
| `GOOGLE_APPLICATION_CREDENTIALS` | No | Path to Google Cloud service account JSON (optional TTS upgrade) |
| `PORT` | No | Server port, default 8000 |

See `.env.example` for the full list (`ASR_BACKEND`, `TTS_BACKEND`, local GPU options).

## TTS Engine

The server uses **edge-tts** — completely free, no account or API key needed.
Voice: `en-IN-NeerjaNeural` (Indian English, female, neural quality).

Other available Indian English voices you can pass as `voice_id`:
- `en-IN-PrabhatNeural` — male
- `en-IN-AaravNeural` — male, different accent

See [`documentation/ai_server_setup.md`](../documentation/ai_server_setup.md) for full setup instructions.
