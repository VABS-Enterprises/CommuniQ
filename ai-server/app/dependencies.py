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

    When the env var is absent, this dependency is a no-op — but only in
    development. settings.validate() (called at startup, see app/main.py)
    hard-fails the process when ENVIRONMENT=production and no key is set, so
    the no-op path below should be unreachable in production. The explicit
    is_production check here is a defense-in-depth backstop in case
    validate() is ever skipped or misconfigured.
    Node's fastApiService.js sends this header on every call.
    """
    expected = settings.internal_api_key
    if not expected:
        if settings.is_production:
            # Should never happen — settings.validate() fails startup first.
            raise HTTPException(status_code=401, detail="Unauthorized")
        return  # no key configured — skip auth (dev mode)
    if x_ai_server_key != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
