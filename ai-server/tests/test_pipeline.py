"""
CommuniQ AI Server — End-to-End Test Pipeline

Tests all endpoints against a running server at http://localhost:8000.

Usage:
    1. Activate venv:   venv\\Scripts\\activate
    2. Start server:    uvicorn app.main:app --reload --port 8000
    3. Run tests:       python -m tests.test_pipeline
                        (run from the ai-server/ directory)

Each test prints a clear PASS / FAIL with details.
Audio output files are saved in the tests/ directory for manual listening.
"""

import base64
import json
import os
import sys

import httpx

BASE_URL = "http://localhost:8000"

# ─── Sample data matching Node's exact request shapes ─────────────────────────

SAMPLE_SYSTEM_PROMPT = (
    "You are a senior HR manager at a mid-size Indian tech company. "
    "You are conducting a behavioral interview for a junior software engineer role. "
    "Ask one STAR-format question at a time. Never give coaching or hints mid-session. "
    "Stay in character throughout. Be direct and professional."
)

SAMPLE_CONVERSATION_HISTORY = json.dumps([
    {"role": "ai",   "transcript": "Tell me about yourself and your background.", "timestamp": "2026-03-21T10:00:00Z"},
    {"role": "user", "transcript": "I have 2 years of experience in backend development using Python and Node.js.", "timestamp": "2026-03-21T10:00:05Z"},
])

SAMPLE_FULL_TRANSCRIPT = (
    "AI: Tell me about a time you faced a difficult challenge at work.\n"
    "User: Um, so basically, like, I had this project where we had to, you know, "
    "build a feature in two days and it was kind of stressful but we managed somehow.\n"
    "AI: Can you be more specific about what made it difficult?\n"
    "User: Uh, yeah so the thing is we didn't have proper requirements and um "
    "the client kept changing things you know what I mean.\n"
    "AI: What did you do to manage the changing requirements?\n"
    "User: So like I basically talked to the team and we decided to just, "
    "you know, prioritize the core features first and honestly it worked out."
)


def separator(title: str) -> None:
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


# ─── Test /health ──────────────────────────────────────────────────────────────

def test_health() -> bool:
    separator("TEST: GET /health")
    try:
        r = httpx.get(f"{BASE_URL}/health", timeout=5)
        r.raise_for_status()
        data = r.json()
        print(f"  Response: {data}")
        assert data.get("status") == "ok", "Expected status: ok"
        assert "groq_ready" in data, "Missing 'groq_ready' field"
        assert "backends" in data, "Missing 'backends' field"
        b = data["backends"]
        assert "asr" in b and "llm" in b and "tts" in b, "Incomplete backends"
        assert "local_models" in data, "Missing 'local_models' field"
        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /tts ────────────────────────────────────────────────────────────────

def test_tts() -> bool:
    separator("TEST: POST /tts")
    payload = {
        "text": "Hello! I am Meera, your HR interviewer today. Please tell me about yourself.",
    }
    try:
        r = httpx.post(f"{BASE_URL}/tts", json=payload, timeout=30)
        r.raise_for_status()
        assert r.headers["content-type"].startswith("audio/mpeg"), (
            f"Expected audio/mpeg, got {r.headers['content-type']}"
        )
        out_dir = os.path.dirname(os.path.abspath(__file__))
        output_path = os.path.join(out_dir, "test_tts_output.mp3")
        with open(output_path, "wb") as f:
            f.write(r.content)
        print(f"  Audio saved: {output_path} ({len(r.content):,} bytes)")
        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /session/evaluate ───────────────────────────────────────────────────

def test_evaluate() -> bool:
    separator("TEST: POST /session/evaluate")
    # Matches Node's fastApiService.evaluateSession() payload exactly
    payload = {
        "sessionId":      "test-session-001",
        "fullTranscript": SAMPLE_FULL_TRANSCRIPT,
        "scenarioType":   "hr_interview",
    }
    try:
        r = httpx.post(f"{BASE_URL}/session/evaluate", json=payload, timeout=60)
        r.raise_for_status()
        data = r.json()

        print("  Evaluation result:")
        print(json.dumps(data, indent=4))

        # Verify Node-contract response shape
        assert "scores" in data,                    "Missing 'scores'"
        assert "fillerWordCount" in data,           "Missing 'fillerWordCount' (was 'filler_count')"
        assert "fillerWords" in data,               "Missing 'fillerWords' (was 'filler_words')"
        assert "strengths" in data,                 "Missing 'strengths'"
        assert "improvements" in data,              "Missing 'improvements'"
        assert "recommendedNextType" in data, "Missing 'recommendedNextType' (was 'recommendedNextScenarioId')"

        # Verify score scale is 0-100
        scores = data["scores"]
        for key in ("clarity", "fluency", "confidence", "vocabulary", "grammar"):
            assert key in scores, f"Missing score key '{key}'"
            val = scores[key]
            assert isinstance(val, int) and 0 <= val <= 100, (
                f"Score '{key}' must be int 0-100, got: {val}"
            )

        assert len(data["strengths"]) == 2,    f"Expected 2 strengths, got {len(data['strengths'])}"
        assert len(data["improvements"]) == 2, f"Expected 2 improvements, got {len(data['improvements'])}"

        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /session/turn ───────────────────────────────────────────────────────

def test_turn() -> bool:
    separator("TEST: POST /session/turn")

    sample_audio_path = _get_sample_audio()
    if sample_audio_path is None:
        print("  SKIP — No sample audio file found.")
        print("  To run this test, place a short audio recording named")
        print("  'sample_audio.m4a' (or .wav / .webm) in the ai-server/ folder.")
        return True

    print(f"  Using audio: {sample_audio_path}")

    try:
        with open(sample_audio_path, "rb") as audio_file:
            # Matches Node's fastApiService.sendTurnToFastApi() multipart payload exactly
            r = httpx.post(
                f"{BASE_URL}/session/turn",
                data={
                    "sessionId":            "test-session-001",
                    "conversationHistory":  SAMPLE_CONVERSATION_HISTORY,
                    "systemPrompt":         SAMPLE_SYSTEM_PROMPT,
                },
                files={
                    "audioFile": (os.path.basename(sample_audio_path), audio_file, "audio/wav"),
                },
                timeout=60,
            )
        r.raise_for_status()
        data = r.json()

        # Verify Node-contract response shape
        assert "userTranscript" in data,  "Missing 'userTranscript'"
        assert "aiReply" in data,         "Missing 'aiReply'"
        assert "aiAudioBase64" in data,   "Missing 'aiAudioBase64'"

        print(f"  userTranscript: {data['userTranscript']}")
        print(f"  aiReply:        {data['aiReply']}")
        print(f"  aiAudioBase64:  {len(data['aiAudioBase64'])} chars (base64)")

        # Decode and save audio for manual listening
        audio_bytes = base64.b64decode(data["aiAudioBase64"])
        out_dir = os.path.dirname(os.path.abspath(__file__))
        output_path = os.path.join(out_dir, "test_turn_output.mp3")
        with open(output_path, "wb") as f:
            f.write(audio_bytes)
        print(f"  Audio saved: {output_path} ({len(audio_bytes):,} bytes)")

        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


def _get_sample_audio() -> str | None:
    search_dirs = [
        os.path.dirname(os.path.abspath(__file__)),  # tests/
        os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."),  # ai-server/
    ]
    for d in search_dirs:
        for name in ("sample_audio.m4a", "sample_audio.wav", "sample_audio.webm", "sample_audio.mp3"):
            path = os.path.join(d, name)
            if os.path.exists(path):
                return path
    return None


# ─── Runner ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\nCommuniQ AI Server — Test Pipeline")
    print("Server must be running: uvicorn app.main:app --reload --port 8000\n")

    results = {
        "GET  /health":            test_health(),
        "POST /tts":               test_tts(),
        "POST /session/evaluate":  test_evaluate(),
        "POST /session/turn":      test_turn(),
    }

    separator("RESULTS SUMMARY")
    all_passed = True
    for name, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  {name:<30} {status}")
        if not passed:
            all_passed = False

    print()
    sys.exit(0 if all_passed else 1)
