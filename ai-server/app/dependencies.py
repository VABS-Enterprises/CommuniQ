from typing import Optional

from fastapi import Header, HTTPException, Request
from groq import AsyncGroq

from app.config import settings


def get_groq_client(request: Request) -> Optional[AsyncGroq]:
    """
    Shared AsyncGroq client from app state, or None when no Groq backend is active
    (fully local ASR/LLM/eval still works via Ollama / vLLM / local Whisper).
    """
    return getattr(request.app.state, "groq_client", None)


def verify_internal_api_key(x_ai_server_key: Optional[str] = Header(default=None)) -> None:
    """
    FastAPI dependency that enforces the internal API key on non-health endpoints.

    When AI_SERVER_INTERNAL_KEY is set in .env, every request must include:
        X-Ai-Server-Key: <key>

    When the env var is absent (local dev), this dependency is a no-op.
    Node's fastApiService.js sends this header on every call.
    """
    expected = settings.internal_api_key
    if not expected:
        return  # no key configured — skip auth (dev mode)
    if x_ai_server_key != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
