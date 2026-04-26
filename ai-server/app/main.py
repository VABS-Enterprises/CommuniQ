import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from groq import AsyncGroq

from app.api.v1.router import router as v1_router
from app.config import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("communiq")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise shared resources at startup, clean up at shutdown."""
    settings.validate()

    needs_groq = (
        settings.asr_backend == "groq"
        or settings.llm_backend == "groq"
        or settings.eval_llm_backend == "groq"
    )
    if needs_groq:
        app.state.groq_client = AsyncGroq(api_key=settings.groq_api_key)
        logger.info(
            "Groq client initialised (ASR=%s, LLM=%s, eval=%s).",
            settings.asr_backend,
            settings.llm_backend,
            settings.eval_llm_backend,
        )
    else:
        app.state.groq_client = None
        logger.info(
            "Groq client skipped (ASR=%s, LLM=%s, eval=%s, TTS=%s).",
            settings.asr_backend,
            settings.llm_backend,
            settings.eval_llm_backend,
            settings.tts_backend,
        )

    yield

    app.state.groq_client = None
    logger.info("Shutdown complete.")


app = FastAPI(
    title="CommuniQ AI Server",
    version="1.0.0",
    description="Internal AI processing service — called only by the Node backend.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Ai-Server-Key"],
)

# All endpoints are mounted at root level for Node backend URL compatibility:
#   POST /session/turn
#   POST /session/evaluate
#   POST /tts
#   GET  /health
app.include_router(v1_router)
