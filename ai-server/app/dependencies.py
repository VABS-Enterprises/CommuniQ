from fastapi import Request
from groq import AsyncGroq


def get_groq_client(request: Request) -> AsyncGroq:
    """
    FastAPI dependency — returns the shared AsyncGroq client stored in app state.
    Initialised once at startup via the lifespan handler in main.py.
    """
    client: AsyncGroq | None = getattr(request.app.state, "groq_client", None)
    if client is None:
        raise RuntimeError(
            "Groq client not initialised. Server may still be starting up."
        )
    return client
