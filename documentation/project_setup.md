# CommuniQ — Project Setup Guide

This guide covers how to set up the full CommuniQ project locally for development. The project is a monorepo with three sub-projects: a Flutter client, a Python AI server, and a general-purpose server (in progress).

---

## Repository Structure

```
CommuniQ/
├── client/          # Flutter app (Android, iOS, Web, Windows, macOS, Linux)
├── ai-server/       # Python AI backend (FastAPI + Groq + TTS)
├── server/          # General-purpose server (planned)
├── documentation/   # Project docs (you are here)
├── skills/          # Developer reference notes
├── .gitignore
└── README.md
```

---

## Prerequisites

### General
- Git

### For the Flutter Client
- [Flutter SDK](https://docs.flutter.dev/get-started/install) — version `>=3.3.0`
- Dart SDK (comes with Flutter)
- Android Studio or Xcode (for mobile targets)
- A connected device or emulator

### For the AI Server
- Python 3.10 or later
- pip
- A virtual environment tool (`venv` recommended)
- A [Groq API key](https://console.groq.com) — free tier is sufficient

### Optional (for higher-quality TTS)
- A Google Cloud project with Text-to-Speech API enabled
- A service account JSON key file with TTS permissions

---

## Cloning the Repository

```bash
git clone <repo-url>
cd CommuniQ
```

---

## Setting Up the AI Server

### 1. Navigate to the ai-server folder

```bash
cd ai-server
```

### 2. Create and activate a virtual environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS / Linux
python -m venv venv
source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Set up environment variables

Copy the example file and fill in your keys:

```bash
cp .env.example .env
```

Open `.env` and add your credentials:

```
GROQ_API_KEY=your_groq_api_key_here
GOOGLE_APPLICATION_CREDENTIALS=path/to/your/google-key.json   # optional
PORT=8000
```

The server works without `GOOGLE_APPLICATION_CREDENTIALS` — it will use edge-tts (free) as the TTS engine. Set the Google credentials only if you want the higher-quality Neural2 Indian English voice.

### 5. Start the server

```bash
uvicorn main:app --reload --port 8000
```

The server will be available at `http://localhost:8000`.

### 6. Verify it's working

```bash
python test_pipeline.py
```

This runs end-to-end tests across all three API endpoints and saves sample audio output.

---

## Setting Up the Flutter Client

### 1. Navigate to the client folder

```bash
cd client
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Configure the AI server URL

The Flutter app needs to know where the AI server is running. During local development, the server runs on `localhost:8000`. For testing on a physical device, you will need to expose the server via ngrok (see below).

### 4. Run the app

```bash
# Run on a connected device or emulator
flutter run

# Run specifically on Android
flutter run -d android

# Run on Chrome (web)
flutter run -d chrome
```

---

## Exposing the AI Server to a Physical Device (ngrok)

When testing on a real Android or iOS device, `localhost` on your machine is not reachable from the device. Use ngrok to expose the server:

### 1. Install ngrok

Download from [ngrok.com](https://ngrok.com) or install via package manager:

```bash
# macOS (Homebrew)
brew install ngrok

# Windows (Chocolatey)
choco install ngrok
```

### 2. Start a tunnel

With the AI server already running on port 8000:

```bash
ngrok http 8000
```

### 3. Copy the forwarding URL

ngrok will display a URL like `https://abc123.ngrok.io`. Use this as the base URL in the Flutter app's API configuration.

---

## Git Branches

| Branch | Purpose |
|---|---|
| `main` | Stable, reviewed code only |
| `AI-server` | AI server development (active) |
| `client-dev` | Flutter client development |

Always branch off `main` for new features. Open a pull request to merge back.

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `GROQ_API_KEY` | Yes | Groq API key for LLM and Whisper STT |
| `GOOGLE_APPLICATION_CREDENTIALS` | No | Path to Google Cloud service account JSON for premium TTS |
| `PORT` | No | Port for the AI server (default: 8000) |

---

## Common Issues

**`GROQ_API_KEY not set` error on server start**
Make sure your `.env` file exists in the `ai-server/` folder and contains the key. The file must not be named `.env.example`.

**Flutter can't reach the server on a physical device**
Use ngrok to expose the server. `localhost` is only accessible from the same machine.

**TTS produces no audio / crashes**
By default the server uses edge-tts, which requires no API key. If you have `GOOGLE_APPLICATION_CREDENTIALS` set but the file path is wrong, TTS will fail. Either fix the path or remove the variable to fall back to edge-tts.

**`flutter pub get` fails**
Ensure you are running Flutter `>=3.3.0`. Run `flutter --version` to check.
