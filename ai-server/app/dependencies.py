from fastapi import HTTPException, Request
from groq import AsyncGroq


def get_groq_client(request: Request) -> AsyncGroq:
    """
    FastAPI dependency — returns the shared AsyncGroq client stored in app state.
    Initialised once at startup via the lifespan handler in main.py.
    """
    client: AsyncGroq | None = getattr(request.app.state, "groq_client", None)
    if client is None:
        raise HTTPException(
            status_code=503,
            detail="AI service not ready. Please try again in a moment.",
        )
    return client
