"""CP1: contract tests for GET /health (no running Groq required with default conftest env)."""

from starlette.testclient import TestClient


def test_health_response_shape() -> None:
    from app.main import app

    with TestClient(app) as client:
        r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "ok"
    assert "groq_ready" in data
    assert data["groq_ready"] is False
    b = data.get("backends") or {}
    assert b.get("asr") == "local"
    assert b.get("llm") == "ollama"
    assert b.get("tts") == "local"
    lm = data.get("local_models") or {}
    assert "whisper_model" in lm
    assert "kokoro_voice" in lm
    assert "ollama_reachable" in data
