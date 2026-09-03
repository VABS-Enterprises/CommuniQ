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


async def _preflight_models(client: AsyncGroq) -> None:
    """
    Check at startup that the key works and the configured models exist.

    Without this, a bad key or a retired model id only surfaces as a failed
    request much later, and the error the user sees ("AI opening failed")
    says nothing about the cause. Groq retired the llama-3.1-* family while
    they were still the configured default, and every conversation and
    evaluation path in the app broke with no startup signal at all.

    Never fatal: the network may simply be unavailable at boot, and refusing
    to start would be worse than serving a health endpoint that reports the
    problem. It logs loudly instead.
    """
    wanted = {settings.llm_model, settings.eval_llm_model}
    try:
        available = {m.id for m in (await client.models.list()).data}
    except Exception as exc:  # noqa: BLE001 - startup diagnostics only
        logger.warning(
            "Could not verify models with Groq (%s). If requests fail later, "
            "check GROQ_API_KEY in ai-server/.env.", exc,
        )
        return

    missing = sorted(m for m in wanted if m not in available)
    if missing:
        logger.error(
            "Configured model(s) not available on this key: %s. "
            "Set LLM_MODEL / EVAL_LLM_MODEL in ai-server/.env to one of: %s",
            ", ".join(missing),
            ", ".join(sorted(available)),
        )
    else:
        logger.info("Model preflight OK — %s", ", ".join(sorted(wanted)))


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
        await _preflight_models(app.state.groq_client)
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
