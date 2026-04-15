"""
CommuniQ Pipecat worker — HTTP dispatch server.

The Node backend calls POST /start-agent once per session (from
livekitService.dispatchAgent) immediately after the opening response is sent
to Flutter. This worker spawns one asyncio background task per session that
runs the full Pipecat voice pipeline until Flutter disconnects.

Start:
    uvicorn worker:app --host 0.0.0.0 --port 9000

Environment variables (see .env):
    GROQ_API_KEY          — Groq cloud API key (STT + LLM + TTS)
    NODE_BACKEND_URL      — e.g. http://localhost:3000
    PIPECAT_WEBHOOK_SECRET — shared secret for /sessions/internal/live-voice-turn
    PORT                  — port to bind (default 9000)
"""

import asyncio
import logging
import os
from contextlib import asynccontextmanager
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from bot import run_bot

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("communiq.worker")

# ─── Active bot tasks ─────────────────────────────────────────────────────────
# Maps session_id → asyncio.Task so we can detect duplicates and clean up.
_active_bots: dict[str, asyncio.Task] = {}


def _on_bot_done(session_id: str, task: asyncio.Task) -> None:
    """Callback fired when a bot task finishes (success or error)."""
    _active_bots.pop(session_id, None)
    if task.cancelled():
        logger.info("[%s] Bot task cancelled.", session_id)
    elif task.exception():
        logger.error("[%s] Bot task raised: %s", session_id, task.exception())
    else:
        logger.info("[%s] Bot task completed normally.", session_id)


# ─── Lifespan ─────────────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(
        "CommuniQ Pipecat worker starting — NODE_BACKEND_URL=%s",
        os.getenv("NODE_BACKEND_URL", "http://localhost:3000"),
    )
    yield
    # Cancel any bots still running on shutdown
    if _active_bots:
        logger.info("Cancelling %d active bot(s) on shutdown...", len(_active_bots))
        for session_id, task in list(_active_bots.items()):
            task.cancel()
            try:
                await asyncio.wait_for(asyncio.shield(task), timeout=3.0)
            except (asyncio.CancelledError, asyncio.TimeoutError):
                pass
    logger.info("Worker shutdown complete.")


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="CommuniQ Pipecat Worker",
    version="1.0.0",
    description="Dispatches one Pipecat LiveKit bot per active roleplay session.",
    lifespan=lifespan,
)


# ─── Request schema ───────────────────────────────────────────────────────────


class StartAgentRequest(BaseModel):
    session_id: str
    livekit_url: str
    agent_token: str
    system_prompt: str
    groq_api_key: Optional[str] = None


# ─── Routes ───────────────────────────────────────────────────────────────────


@app.get("/health")
async def health() -> JSONResponse:
    return JSONResponse(
        {
            "status": "ok",
            "active_bots": len(_active_bots),
            "sessions": list(_active_bots.keys()),
        }
    )


@app.post("/start-agent", status_code=202)
async def start_agent(req: StartAgentRequest) -> JSONResponse:
    """
    Called by the Node backend (livekitService.dispatchAgent) after the
    HTTP opening response is delivered to Flutter.

    Returns 202 Accepted immediately — the bot runs in the background.
    """
    session_id = req.session_id.strip()

    if not session_id:
        raise HTTPException(status_code=400, detail="session_id is required")
    if not req.livekit_url.strip():
        raise HTTPException(status_code=400, detail="livekit_url is required")
    if not req.agent_token.strip():
        raise HTTPException(status_code=400, detail="agent_token is required")
    if not req.system_prompt.strip():
        raise HTTPException(status_code=400, detail="system_prompt is required")

    # Prevent duplicate bots for the same session
    if session_id in _active_bots and not _active_bots[session_id].done():
        logger.warning(
            "[%s] Bot already running — ignoring duplicate /start-agent", session_id
        )
        return JSONResponse(
            {"status": "already_running", "session_id": session_id}, status_code=202
        )

    task = asyncio.create_task(
        run_bot(
            session_id=session_id,
            livekit_url=req.livekit_url,
            agent_token=req.agent_token,
            system_prompt=req.system_prompt,
            groq_api_key=req.groq_api_key,
        ),
        name=f"bot-{session_id}",
    )
    task.add_done_callback(lambda t: _on_bot_done(session_id, t))
    _active_bots[session_id] = task

    logger.info("[%s] Bot task spawned.", session_id)
    return JSONResponse({"status": "started", "session_id": session_id}, status_code=202)


@app.delete("/bots/{session_id}", status_code=200)
async def stop_bot(session_id: str) -> JSONResponse:
    """
    Manually cancel a running bot — useful for testing or forceful cleanup.
    The Node /sessions/end endpoint deletes the LiveKit room, which will
    trigger on_participant_left and end the pipeline naturally; this route
    is an emergency kill-switch.
    """
    task = _active_bots.get(session_id)
    if task is None or task.done():
        raise HTTPException(status_code=404, detail="No active bot for this session")

    task.cancel()
    return JSONResponse({"status": "cancelled", "session_id": session_id})
