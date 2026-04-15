from typing import Optional

from fastapi import Request
from groq import AsyncGroq


def get_groq_client(request: Request) -> Optional[AsyncGroq]:
    """
    Shared AsyncGroq client from app state, or None when no Groq backend is active
    (fully local ASR/LLM/eval still works via Ollama / vLLM / local Whisper).
    """
    return getattr(request.app.state, "groq_client", None)
