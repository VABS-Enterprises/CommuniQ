# CommuniQ — AI Based Conversation Simulator

CommuniQ is an AI-powered voice-based communication practice app built for Indian students and professionals. It lets you have real, pressure-tested conversations with AI characters so you can sharpen your communication skills before it counts.

You speak. An AI character responds. You get evaluated. You improve.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Step-by-Step Setup](#step-by-step-setup)
   - [1. Clone the repo](#1-clone-the-repo)
   - [2. Firebase setup](#2-firebase-setup)
   - [3. Groq API key](#3-groq-api-key)
   - [4. Node server](#4-node-server)
   - [5. AI server (FastAPI)](#5-ai-server-fastapi)
   - [6. Pipecat worker (live voice)](#6-pipecat-worker-live-voice)
   - [7. Flutter client](#7-flutter-client)
5. [Running the Project](#running-the-project)
6. [Seeding Scenarios](#seeding-scenarios)
7. [Environment Variable Reference](#environment-variable-reference)
8. [Practice Scenarios](#practice-scenarios)
9. [Performance Evaluation](#performance-evaluation)

---

## Architecture Overview

```
Flutter app (phone)
    │  Firebase ID token (auth)
    ▼
Node API  (port 3000)
    │  session management, auth, Firestore writes
    ├──► FastAPI ai-server (port 8000)  — opening turn + evaluation
    └──► Pipecat worker  (port 9000)  — live voice turns via LiveKit (WebRTC)

Cloud services used:
  Groq     — Whisper STT  +  Llama 3.1 8B LLM
  Edge TTS — text-to-speech (free, no key)
  Firebase — Firestore database + Auth
  LiveKit  — WebRTC media server (cloud or self-hosted)
```

**Live voice flow (one turn):**
```
User mic → LiveKit → Pipecat worker → Groq Whisper (STT)
                                    → Groq Llama (LLM)
                                    → Edge TTS
                                    → LiveKit → User speaker
```

---

## Prerequisites

Install these before anything else.

| Tool | Version | Download |
|------|---------|----------|
| Node.js | 18+ | https://nodejs.org |
| Python | 3.11 or 3.12 (not 3.13 for Kokoro TTS) | https://python.org |
| Flutter | 3.x (stable) | https://flutter.dev/docs/get-started/install |
| Git | any | https://git-scm.com |
| Docker Desktop | (only if self-hosting LiveKit) | https://docker.com |

---

## Repository Structure

```
CommuniQ/
├── server/              Node.js backend (auth, sessions, Firestore)
├── ai-server/           FastAPI — opening turn + session evaluation
├── pipecat-worker/      Pipecat live-voice agent (WebRTC via LiveKit)
├── client/              Flutter app
├── livekit/             Self-hosted LiveKit config (docker-compose)
├── training/            Dataset scripts + fine-tuning pipeline (offline)
└── docs/                Architecture and API contract docs
```

---

## Step-by-Step Setup

### 1. Clone the repo

```bash
git clone https://github.com/VABS-Enterprises/CommuniQ.git
cd CommuniQ
git checkout version-one
```

---

### 2. Firebase setup

CommuniQ uses Firebase for **authentication** and **Firestore** as the database.

1. Go to [Firebase Console](https://console.firebase.google.com) and open the **communiq-f32a0** project (ask a team member for access), or create a new project for local dev.
2. Go to **Project Settings → Service Accounts → Generate new private key** → download the JSON file.
3. Open the JSON and copy three values into your `server/.env` (see step 4):
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `client_email` → `FIREBASE_CLIENT_EMAIL`
   - `private_key` → `FIREBASE_PRIVATE_KEY`

4. In Firebase Console → **Authentication → Sign-in methods**, enable **Email/Password**.
5. In Firebase Console → **Firestore Database**, create a database in **production mode** (or test mode for local dev).

---

### 3. Groq API key

CommuniQ uses Groq for STT (Whisper) and LLM (Llama 3.1 8B).

1. Sign up at [console.groq.com](https://console.groq.com) (free tier is sufficient for development).
2. Go to **API Keys → Create API Key**.
3. Copy the key — it starts with `gsk_`.

You will use this key in both `ai-server/.env` and `pipecat-worker/.env`.

---

### 4. Node server

```bash
cd server
npm install
```

Create `server/.env`:

```env
PORT=3000
NODE_ENV=development

# Firebase Admin SDK
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your_project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# FastAPI ai-server URL
FASTAPI_URL=http://localhost:8000

# Admin
ADMIN_SECRET=communiq-dev-secret
ALLOWED_ORIGINS=*

# LiveKit (cloud) — sign up free at https://cloud.livekit.io
LIVEKIT_ENABLED=true
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret

# Pipecat worker
PIPECAT_WORKER_URL=http://localhost:9000
PIPECAT_WEBHOOK_SECRET=communiq-pipecat-secret-dev
```

> **LiveKit Cloud (easiest):** Sign up at https://cloud.livekit.io → create a project → copy URL / Key / Secret.
>
> **Self-hosted LiveKit (no account needed):** Run `cd livekit && docker compose up -d` and use:
> ```
> LIVEKIT_URL=ws://localhost:7880
> LIVEKIT_API_KEY=devkey
> LIVEKIT_API_SECRET=communiq-local-dev-livekit-secret-min-32ch
> ```

---

### 5. AI server (FastAPI)

```bash
cd ai-server

# Create a virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate          # Windows
source venv/bin/activate       # macOS / Linux

# Install dependencies
pip install -r requirements.txt
```

Create `ai-server/.env`:

```env
GROQ_API_KEY=gsk_your_key_here
PORT=8000
ASR_BACKEND=groq
LLM_BACKEND=groq
TTS_BACKEND=edge
EVAL_LLM_BACKEND=groq
LLM_MODEL=llama-3.1-8b-instant
EVAL_LLM_MODEL=llama-3.1-8b-instant
```

---

### 6. Pipecat worker (live voice)

The Pipecat worker runs the real-time voice pipeline for live conversations.

```bash
cd pipecat-worker

# Install dependencies (uses the system Python or a venv)
pip install -r requirements.txt
```

Create `pipecat-worker/.env`:

```env
PORT=9000

# Groq — same key as ai-server
GROQ_API_KEY=gsk_your_key_here

# Node backend URL (for posting turn transcripts back)
NODE_BACKEND_URL=http://localhost:3000

# Shared secret — must match PIPECAT_WEBHOOK_SECRET in server/.env
PIPECAT_WEBHOOK_SECRET=communiq-pipecat-secret-dev
```

> Note: LiveKit credentials are sent by Node at runtime — you do **not** need them in this `.env`.

---

### 7. Flutter client

```bash
cd client
flutter pub get
```

Open `client/lib/core/services/api_service.dart` and confirm `baseUrl` points to your Node server:

- **Emulator / same machine:** `http://10.0.2.2:3000` (Android emulator) or `http://localhost:3000` (iOS sim / web)
- **Physical device:** Use an ngrok tunnel — run `ngrok http 3000` and paste the `https://` URL

Then run:

```bash
flutter run
```

---

## Running the Project

Open **4 terminals** from the repo root.

| Terminal | Command | What it does |
|----------|---------|-------------|
| **1 — Node** | `cd server && npm start` | Auth, sessions, Firestore |
| **2 — ai-server** | `cd ai-server && venv\Scripts\activate && uvicorn app.main:app --reload --port 8000` | Opening turn + evaluation |
| **3 — Pipecat** | `cd pipecat-worker && uvicorn worker:app --host 0.0.0.0 --port 9000` | Live voice pipeline |
| **4 — Flutter** | `cd client && flutter run` | Mobile app |

**Verify each service is up:**

```
http://localhost:3000          → Node (any response = OK)
http://localhost:8000/health   → {"status":"ok",...}
http://localhost:9000/health   → {"status":"ok","active_bots":0,...}
```

---

## Seeding Scenarios

On a fresh database, seed the default practice scenarios:

```bash
cd server
node scripts/seed-scenarios.js
```

This adds all built-in HR, Technical, GD, and Sales scenarios to Firestore.

---

## Environment Variable Reference

### `server/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Node port (default 3000) |
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Yes | Service account email |
| `FIREBASE_PRIVATE_KEY` | Yes | Service account private key |
| `FASTAPI_URL` | Yes | URL of the ai-server (default `http://localhost:8000`) |
| `ADMIN_SECRET` | Yes | Secret for admin-only endpoints |
| `LIVEKIT_ENABLED` | No | `true` to enable live voice mode |
| `LIVEKIT_URL` | If enabled | LiveKit server WebSocket URL |
| `LIVEKIT_API_KEY` | If enabled | LiveKit API key |
| `LIVEKIT_API_SECRET` | If enabled | LiveKit API secret |
| `PIPECAT_WORKER_URL` | If enabled | Pipecat worker URL (default `http://localhost:9000`) |
| `PIPECAT_WEBHOOK_SECRET` | If enabled | Shared secret between Node and Pipecat worker |

### `ai-server/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes | Groq cloud API key |
| `PORT` | No | FastAPI port (default 8000) |
| `ASR_BACKEND` | No | `groq` (default) |
| `LLM_BACKEND` | No | `groq` (default) |
| `TTS_BACKEND` | No | `edge` (default) |
| `LLM_MODEL` | No | Groq model for conversation (default `llama-3.1-8b-instant`) |
| `EVAL_LLM_MODEL` | No | Groq model for evaluation (default `llama-3.1-8b-instant`) |

### `pipecat-worker/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Worker port (default 9000) |
| `GROQ_API_KEY` | Yes | Same Groq key as ai-server |
| `NODE_BACKEND_URL` | Yes | Node backend URL for posting turn transcripts |
| `PIPECAT_WEBHOOK_SECRET` | Yes | Must match `server/.env` |

---

## Practice Scenarios

| Type | Description |
|------|-------------|
| **HR Interview** | Behavioural questions, STAR probing, confidence testing |
| **Technical Interview** | System design, trade-offs, depth over buzzwords |
| **Group Discussion** | Topic-based debate with a neutral AI moderator |
| **Sales Call** | Pitch to a skeptical client, handle objections |

Difficulty levels: **Beginner → Intermediate → Advanced**

---

## Performance Evaluation

After every session you receive:

- **Six skill scores (0–100):** Clarity, Fluency, Confidence, Vocabulary, Grammar, Pronunciation
- **Filler word count** — which fillers appeared and how often
- **Two specific strengths** from that session (quoted from your speech)
- **Two actionable improvements** with before/after examples
- **Recommended next scenario** (e.g. `hr_interview_intermediate`)

---

*CommuniQ — Practice the conversation before it happens.*
