# CommuniQ — AI-Based Conversation Simulator

CommuniQ is an AI-powered, voice-first communication practice app built for Indian students and professionals. You hold real, pressure-tested conversations with AI characters — interviewers, clients, GD moderators — and get a detailed evaluation of how you spoke, so you can sharpen your skills before the conversation that counts.

> **You speak. An AI character responds. You get evaluated. You improve.**

---

## Table of Contents

1. [Key Features](#key-features)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Repository Structure](#repository-structure)
5. [Prerequisites](#prerequisites)
6. [Setup](#setup)
7. [Running the Project](#running-the-project)
8. [Testing](#testing)
9. [Environment Variable Reference](#environment-variable-reference)
10. [API Overview](#api-overview)
11. [Deployment](#deployment)
12. [Further Documentation](#further-documentation)

---

## Key Features

| Feature | Description |
|---------|-------------|
| **Live voice roleplay** | Real-time, low-latency voice conversations with an AI character over WebRTC (LiveKit + Pipecat). |
| **Practice scenarios** | HR interview, technical interview, group discussion and sales call — each at Beginner, Intermediate and Advanced difficulty. |
| **Session evaluation** | Six skill scores (Clarity, Fluency, Confidence, Vocabulary, Grammar, Pronunciation), a filler-word breakdown, quoted strengths, actionable improvements with before/after examples, and a recommended next scenario. |
| **Visual analysis** | On-device eye-contact (gaze) and posture tracking through the camera using Google ML Kit face detection, shown as a gaze radar, a distribution chart and AI coaching tips. |
| **Guided learning path** | 20 structured levels of bite-sized lessons with progress tracking. |
| **Contests and leaderboards** | Timed speaking contests, contest history, and weekly and all-time leaderboards. |
| **Personalised onboarding** | A multi-step flow (goals, speaking style, challenges, skill level) that builds a practice plan. |
| **Offline resilience** | Cached API responses and an encrypted local profile cache keep the app usable on flaky networks. |
| **Authentication** | Firebase Auth with Email/Password and Google Sign-In. |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile client | Flutter (Dart 3), Provider, Dio, LiveKit client, ML Kit Face Detection, camera, just_audio |
| Backend API | Node.js, Express, Firebase Admin SDK, LiveKit Server SDK, Helmet, express-rate-limit |
| AI server | Python, FastAPI, Groq (Whisper STT + LLM), Edge TTS / Kokoro TTS |
| Real-time voice | Pipecat, LiveKit (WebRTC), Silero VAD |
| Database and auth | Firebase Firestore, Firebase Authentication |
| Model training (offline) | QLoRA fine-tuning with Unsloth, Ollama Modelfile |
| Deployment | Render (`render.yaml`), Docker (Pipecat worker, self-hosted LiveKit) |

---

## Architecture

```
            Flutter app (Android / iOS / Web)
                         │  Firebase ID token on every request
                         ▼
               Node API  (Express, port 3000)
     auth · sessions · scenarios · levels · contests · Firestore
                │                               │
                ▼                               ▼
   FastAPI ai-server (port 8000)       Pipecat worker (port 9000)
   opening turn · STT · TTS ·          live voice turns over
   evaluation (roleplay / learning /   LiveKit (WebRTC)
   contest)

Cloud services:
  Groq      — Whisper STT + LLM inference
  Edge TTS  — text-to-speech (free, no key)
  Firebase  — Firestore database + Authentication
  LiveKit   — WebRTC media server (cloud or self-hosted)
```

**Live voice flow (one turn):**

```
User mic → LiveKit → Pipecat worker → Groq Whisper (STT)
                                    → Groq LLM (character reply)
                                    → Edge TTS
                                    → LiveKit → User speaker
                     Pipecat worker → Node API (transcript saved to Firestore)
```

When the session ends, the Node API sends the full transcript to the ai-server for evaluation and stores the report in Firestore.

A detailed walkthrough is in [`documentation/architecture.md`](documentation/architecture.md).

---

## Repository Structure

```
CommuniQ/
├── client/            Flutter mobile app
│   └── lib/
│       ├── core/          routing, services (API, auth, gaze detection, offline cache …)
│       ├── models/        data models
│       ├── common_widgets/
│       └── views/         auth, onboarding, home, roleplay, learning,
│                          contest, visual_analysis, profile, premium
├── server/            Node.js / Express backend (auth, sessions, Firestore)
├── ai-server/         FastAPI service — STT, TTS, opening turn, evaluation
├── pipecat-worker/    Pipecat real-time voice agent (WebRTC via LiveKit)
├── livekit/           Self-hosted LiveKit config (docker-compose)
├── training/          Dataset scripts + QLoRA fine-tuning pipeline (offline)
├── documentation/     Setup and architecture guides
├── docs/              API contracts, roadmap, metrics notes
├── firestore.rules    Firestore security rules
└── render.yaml        Render deployment blueprint
```

---

## Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Node.js | 18+ | https://nodejs.org |
| Python | 3.11 or 3.12 (Kokoro TTS does not support 3.13) | https://python.org |
| Flutter | 3.x stable (Dart ≥ 3.3) | https://flutter.dev/docs/get-started/install |
| Git | any | https://git-scm.com |
| ffmpeg | any (needed by the ai-server for audio conversion) | https://ffmpeg.org/download.html |
| Docker Desktop | only if self-hosting LiveKit | https://docker.com |

You also need:

- a **Firebase** project (Auth + Firestore)
- a **Groq** API key — free tier at [console.groq.com](https://console.groq.com)
- a **LiveKit** project — free at [cloud.livekit.io](https://cloud.livekit.io), or self-hosted with Docker

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/VABS-Enterprises/CommuniQ.git
cd CommuniQ
git checkout version-one
```

### 2. Firebase

1. Create a project in the [Firebase Console](https://console.firebase.google.com), or ask a team member for access to the existing one.
2. **Authentication → Sign-in method:** enable **Email/Password** and **Google**.
3. **Firestore Database:** create a database.
4. **Project Settings → Service Accounts → Generate new private key.** From the downloaded JSON, copy `project_id`, `client_email` and `private_key` into `server/.env` (see below).

### 3. Node server

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

# AI server
FASTAPI_URL=http://localhost:8000
AI_SERVER_INTERNAL_KEY=any-long-random-string     # must match ai-server/.env

# Admin
ADMIN_SECRET=change-me
ALLOWED_ORIGINS=*

# LiveKit
LIVEKIT_ENABLED=true
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret

# Pipecat worker
PIPECAT_WORKER_URL=http://localhost:9000
PIPECAT_WEBHOOK_SECRET=any-long-random-string     # must match pipecat-worker/.env
```

> **Self-hosted LiveKit (no account needed):** run `cd livekit && docker compose up -d`, then set
> `LIVEKIT_URL=ws://localhost:7880` and use the key and secret from `livekit/livekit.yaml`.

Seed the practice scenarios and learning levels into a fresh Firestore database:

```bash
node scripts/seed-scenarios.js
npm run levels:sync
```

### 4. AI server (FastAPI)

```bash
cd ai-server
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create `ai-server/.env`:

```env
GROQ_API_KEY=gsk_your_key_here
PORT=8000
AI_SERVER_INTERNAL_KEY=any-long-random-string     # same value as server/.env
ASR_BACKEND=groq
LLM_BACKEND=groq
EVAL_LLM_BACKEND=groq
TTS_BACKEND=edge
```

### 5. Pipecat worker (live voice)

```bash
cd pipecat-worker
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create `pipecat-worker/.env`:

```env
PORT=9000
GROQ_API_KEY=gsk_your_key_here
NODE_BACKEND_URL=http://localhost:3000
PIPECAT_WEBHOOK_SECRET=any-long-random-string     # same value as server/.env
```

> The Node server sends LiveKit room credentials to the worker at runtime, so they are **not** needed here.

### 6. Flutter client

```bash
cd client
flutter pub get
```

The client chooses its backend URL like this:

- **Debug builds:** `http://localhost:3000` (iOS simulator, web, desktop)
- **Release builds:** the deployed Render URL
- **Override:** `--dart-define=SERVER_URL=<url>`, for example:

```bash
# Android emulator
flutter run --dart-define=SERVER_URL=http://10.0.2.2:3000

# Physical device (expose the Node server with `ngrok http 3000`)
flutter run --dart-define=SERVER_URL=https://<your-ngrok-id>.ngrok-free.app
```

---

## Running the Project

Start each service in its own terminal, from the repo root:

| # | Service | Command |
|---|---------|---------|
| 1 | Node API | `cd server && npm run dev` |
| 2 | AI server | `cd ai-server && source venv/bin/activate && uvicorn app.main:app --reload --port 8000` |
| 3 | Pipecat worker | `cd pipecat-worker && source venv/bin/activate && uvicorn main:app --host 0.0.0.0 --port 9000` |
| 4 | Flutter app | `cd client && flutter run` |

**Health checks:**

```
http://localhost:3000            → Node API is up (any response)
http://localhost:8000/health     → {"status":"ok", ...}
http://localhost:9000/health     → {"status":"ok","active_bots":0, ...}
```

---

## Testing

```bash
# Node backend
cd server && npm test

# AI server
cd ai-server && pytest

# Flutter client (unit + widget tests)
cd client && flutter test
```

---

## Environment Variable Reference

### `server/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Node port (default `3000`) |
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Yes | Service-account email |
| `FIREBASE_PRIVATE_KEY` | Yes | Service-account private key |
| `FASTAPI_URL` | Yes | ai-server URL (default `http://localhost:8000`) |
| `AI_SERVER_INTERNAL_KEY` | Yes | Shared server-to-server secret with the ai-server |
| `ADMIN_SECRET` | Yes | Secret for admin-only endpoints |
| `ALLOWED_ORIGINS` | No | CORS allow-list |
| `LIVEKIT_ENABLED` | No | `true` to enable live voice mode |
| `LIVEKIT_URL` / `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET` | If live voice | LiveKit connection details |
| `PIPECAT_WORKER_URL` | If live voice | Pipecat worker URL (default `http://localhost:9000`) |
| `PIPECAT_WEBHOOK_SECRET` | If live voice | Shared secret with the Pipecat worker |

### `ai-server/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes | Groq API key |
| `PORT` | No | FastAPI port (default `8000`) |
| `AI_SERVER_INTERNAL_KEY` | Yes | Same value as in `server/.env` |
| `ASR_BACKEND` | No | `groq` (default) or `local` (faster-whisper, GPU) |
| `LLM_BACKEND` / `EVAL_LLM_BACKEND` | No | `groq` (default); `ollama`, `vllm` or an OpenAI-compatible backend for local models |
| `TTS_BACKEND` | No | `edge` (default) or `local` (Kokoro) |
| `LLM_MODEL` / `EVAL_LLM_MODEL` | No | Model IDs for conversation and evaluation |

### `pipecat-worker/.env`

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT` | No | Worker port (default `9000`) |
| `GROQ_API_KEY` | Yes | Groq API key |
| `NODE_BACKEND_URL` | Yes | Node API URL for posting turn transcripts |
| `PIPECAT_WEBHOOK_SECRET` | Yes | Same value as in `server/.env` |

> `.env` files are git-ignored. Never commit real keys.

---

## API Overview

All Node routes except the health check need a Firebase ID token in the `Authorization: Bearer <token>` header.

| Area | Example endpoints |
|------|-------------------|
| Auth | `POST /auth/register`, `POST /auth/google`, `GET /auth/me`, `DELETE /auth/account` |
| Scenarios | `GET /scenarios`, `GET /scenarios/:scenarioId` |
| Sessions | `POST /sessions/start`, `POST /sessions/livekit-token`, `POST /sessions/turn`, `POST /sessions/end`, `GET /sessions/:sessionId/report` |
| Learning | `GET /learning/progress`, `POST /learning/answer`, `POST /learning/levels/:levelId/complete` |
| Contests | `POST /contest/submit`, `GET /contest/history`, `GET /contest/leaderboard` |
| User | `GET /user/profile`, `PATCH /user/profile`, `POST /user/visual-reports` |

The full request and response contracts are in [`docs/API_CONTRACTS.md`](docs/API_CONTRACTS.md).

---

## Deployment

- **Node API + AI server:** deployed to Render with the blueprint in [`render.yaml`](render.yaml). Fill in every secret marked `sync: false` in the Render dashboard.
- **Pipecat worker:** containerised with [`pipecat-worker/Dockerfile`](pipecat-worker/Dockerfile).
- **LiveKit:** LiveKit Cloud, or self-hosted with [`livekit/docker-compose.prod.yml`](livekit/docker-compose.prod.yml).
- **Firestore rules:** `firebase deploy --only firestore:rules`

---

## Further Documentation

| Document | Contents |
|----------|----------|
| [`documentation/project_setup.md`](documentation/project_setup.md) | Detailed local setup |
| [`documentation/ai_server_setup.md`](documentation/ai_server_setup.md) | AI server backends (cloud and local models) |
| [`documentation/architecture.md`](documentation/architecture.md) | End-to-end architecture and session flow |
| [`docs/API_CONTRACTS.md`](docs/API_CONTRACTS.md) | API request and response contracts |
| [`training/README.md`](training/README.md) | Dataset generation and fine-tuning pipeline |

---

*CommuniQ — Practice the conversation before it happens.*
