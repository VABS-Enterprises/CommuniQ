"""
CommuniQ AI Server — End-to-End Test Pipeline

Tests all three endpoints against a running server at http://localhost:8000.

Usage:
    1. Start the server:   uvicorn main:app --reload --port 8000
    2. Run this script:    python test_pipeline.py

Each test prints a clear PASS / FAIL with details.
Audio output files are saved in the same directory for manual listening.
"""

import base64
import json
import os
import sys

import httpx

BASE_URL = "http://localhost:8000"

SAMPLE_SCENARIO_PROMPT = (
    "You are conducting a behavioral interview for a junior software engineer role. "
    "Ask one STAR-format question at a time about the candidate's past experience, "
    "challenges they have faced, and how they handled them."
)
SAMPLE_AGENT_DESCRIPTION = "Senior HR manager at a mid-size Indian tech company"
SAMPLE_AGENT_VOICE = "formal, measured, direct, no tolerance for vague answers"
SAMPLE_LEVEL = "beginner"

SAMPLE_TRANSCRIPT = (
    "Interviewer: Tell me about a time you faced a difficult challenge at work.\n"
    "User: Um, so basically, like, I had this project where we had to, you know, "
    "build a feature in two days and it was kind of stressful but we managed somehow.\n"
    "Interviewer: Can you be more specific about what made it difficult?\n"
    "User: Uh, yeah so the thing is we didn't have proper requirements and um "
    "the client kept changing things you know what I mean."
)


def separator(title: str) -> None:
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


# ─── Test /health ──────────────────────────────────────────────────────────────

def test_health() -> bool:
    separator("TEST: /health")
    try:
        r = httpx.get(f"{BASE_URL}/health", timeout=5)
        r.raise_for_status()
        print(f"  Response: {r.json()}")
        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /tts ────────────────────────────────────────────────────────────────

def test_tts() -> bool:
    separator("TEST: /tts")
    payload = {
        "text": "Hello! I am Meera, your HR interviewer today. Please tell me about yourself and your background.",
    }
    try:
        r = httpx.post(f"{BASE_URL}/tts", json=payload, timeout=30)
        r.raise_for_status()
        assert r.headers["content-type"].startswith("audio/mpeg"), (
            f"Expected audio/mpeg, got {r.headers['content-type']}"
        )
        output_path = "test_tts_output.mp3"
        with open(output_path, "wb") as f:
            f.write(r.content)
        print(f"  Audio saved: {output_path} ({len(r.content):,} bytes)")
        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /evaluate ───────────────────────────────────────────────────────────

def test_evaluate() -> bool:
    separator("TEST: /evaluate")
    payload = {
        "transcript": SAMPLE_TRANSCRIPT,
        "scenario_prompt": SAMPLE_SCENARIO_PROMPT,
        "agent_description": SAMPLE_AGENT_DESCRIPTION,
        "level": SAMPLE_LEVEL,
    }
    try:
        r = httpx.post(f"{BASE_URL}/evaluate", json=payload, timeout=60)
        r.raise_for_status()
        data = r.json()

        # Spot-check required fields
        assert "scores" in data, "Missing 'scores'"
        assert "strengths" in data, "Missing 'strengths'"
        assert "improvements" in data, "Missing 'improvements'"
        assert len(data["strengths"]) == 2, f"Expected 2 strengths, got {len(data['strengths'])}"
        assert len(data["improvements"]) == 2, f"Expected 2 improvements, got {len(data['improvements'])}"
        assert "recommended_next" in data, "Missing 'recommended_next'"

        print("  Evaluation result:")
        print(json.dumps(data, indent=4))
        print("  PASS")
        return True
    except Exception as e:
        print(f"  FAIL — {e}")
        return False


# ─── Test /conversation ───────────────────────────────────────────────────────

def test_conversation() -> bool:
    separator("TEST: /conversation (SSE stream)")

    sample_audio_path = _get_sample_audio()
    if sample_audio_path is None:
        print("  SKIP — No sample audio file found.")
        print("  To run this test, place a short audio recording named 'sample_audio.m4a'")
        print("  (or .wav / .webm) in the ai-server folder and re-run.")
        return True

    messages = json.dumps([])

    print(f"  Using audio file: {sample_audio_path}")
    print("  Streaming SSE events:\n")

    audio_chunks_received = 0
    text_chunks_received = 0
    transcript_received = False
    done_received = False
    audio_buffer = b""

    try:
        with open(sample_audio_path, "rb") as audio_file:
            with httpx.stream(
                "POST",
                f"{BASE_URL}/conversation",
                data={
                    "messages": messages,
                    "scenario_prompt": SAMPLE_SCENARIO_PROMPT,
                    "agent_description": SAMPLE_AGENT_DESCRIPTION,
                    "agent_voice": SAMPLE_AGENT_VOICE,
                    "level": SAMPLE_LEVEL,
                },
                files={"audio": (os.path.basename(sample_audio_path), audio_file)},
                timeout=120,
            ) as r:
                r.raise_for_status()
                for line in r.iter_lines():
                    if not line.startswith("data:"):
                        continue
                    raw = line[len("data:"):].strip()
                    if not raw:
                        continue
                    event = json.loads(raw)
                    etype = event.get("type")

                    if etype == "transcript":
                        transcript_received = True
                        print(f"  [transcript]   {event['text']}")
                    elif etype == "text_chunk":
                        text_chunks_received += 1
                        print(event["text"], end="", flush=True)
                    elif etype == "audio_chunk":
                        audio_chunks_received += 1
                        chunk_bytes = base64.b64decode(event["data"])
                        audio_buffer += chunk_bytes
                        print(f"\n  [audio_chunk]  chunk {audio_chunks_received} ({len(chunk_bytes):,} bytes)")
                    elif etype == "done":
                        done_received = True
                        print("\n  [done]")
                    elif etype == "error":
                        print(f"\n  [error]  {event.get('message')}")
                        return False

        if audio_buffer:
            out_path = "test_conversation_output.mp3"
            with open(out_path, "wb") as f:
                f.write(audio_buffer)
            print(f"\n  Full audio saved: {out_path} ({len(audio_buffer):,} bytes)")

        assert transcript_received, "No transcript event received"
        assert text_chunks_received > 0, "No text_chunk events received"
        assert audio_chunks_received > 0, "No audio_chunk events received"
        assert done_received, "No done event received"

        print(f"\n  Summary: {text_chunks_received} text chunks, {audio_chunks_received} audio chunks")
        print("  PASS")
        return True

    except Exception as e:
        print(f"\n  FAIL — {e}")
        return False


def _get_sample_audio() -> str | None:
    for name in ("sample_audio.m4a", "sample_audio.wav", "sample_audio.webm", "sample_audio.mp3"):
        if os.path.exists(name):
            return name
    return None


# ─── Runner ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("\nCommuniQ AI Server — Test Pipeline")
    print("Make sure the server is running: uvicorn main:app --reload --port 8000\n")

    results = {
        "health":       test_health(),
        "tts":          test_tts(),
        "evaluate":     test_evaluate(),
        "conversation": test_conversation(),
    }

    separator("RESULTS SUMMARY")
    all_passed = True
    for name, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  {name:<20} {status}")
        if not passed:
            all_passed = False

    print()
    sys.exit(0 if all_passed else 1)
