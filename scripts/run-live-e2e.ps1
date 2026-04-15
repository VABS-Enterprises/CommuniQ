# CommuniQ — run all processes needed for a local live-voice smoke test (Windows).
# Run each block in its own terminal, in order 1 → 5.
#
# Before testing on a physical phone: set Node and Pipecat LIVEKIT_URL to your PC's
# LAN IP (e.g. ws://192.168.1.42:7880), not localhost.

Write-Host @"

=== 1) LiveKit (this folder: repo/livekit) ===
  cd livekit
  docker compose up -d
  curl http://127.0.0.1:7880

=== 2) Ollama (same machine as Pipecat worker) ===
  ollama serve
  ollama pull llama3.2:3b

=== 3) Pipecat worker ===
  cd pipecat-worker
  copy .env.example .env
  # Edit .env: WHISPER_DEVICE=cpu or cuda, LLM_BASE_URL, LIVEKIT_URL
  pip install -r requirements.txt
  `$env:PYTHONPATH='.'
  uvicorn main:app --host 0.0.0.0 --port 9000

=== 4) Node API ===
  cd server
  # In .env set:
  #   LIVEKIT_ENABLED=true
  #   LIVEKIT_URL=ws://127.0.0.1:7880
  #   LIVEKIT_API_KEY=devkey
  #   LIVEKIT_API_SECRET=communiq-local-dev-livekit-secret-min-32ch
  #   PIPECAT_WORKER_URL=http://127.0.0.1:9000
  npm start

=== 5) AI server (Groq path for opening/turn HTTP) ===
  cd ai-server
  # Use your usual .env (GROQ_API_KEY, etc.)
  uvicorn app.main:app --reload --port 8000

=== 6) Flutter ===
  cd client
  flutter run --dart-define=SERVER_URL=http://10.0.2.2:3000
  # Android emulator: 10.0.2.2 = host loopback. Use your LAN IP for a real phone.

Smoke checks:
  - After opening audio, log shows [LiveVoice] Connected
  - Pipecat logs show agent starting and (after you speak) transcription + TTS
  - You hear the AI reply from the device speaker (WebRTC), not only the opening MP3

Note: End-session feedback still expects HTTP /sessions/turn turns in Firestore.
Live mode is for verifying WebRTC + Pipecat audio; full product sync is a follow-up.

"@
