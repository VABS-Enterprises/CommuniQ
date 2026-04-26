"""
CommuniQ Pipecat Worker — HTTP trigger server.

Exposes a single endpoint:
  POST /start-agent   { session_id, livekit_url, agent_token, system_prompt }

Node calls this after generating the opening AI line (sessionOpening).
The worker spawns an asyncio task that runs the Pipecat pipeline for the
session. The agent joins the LiveKit room and handles audio for the full
session lifetime.

Start:
  uvicorn main:app --port 9000 --host 0.0.0.0
"""

import asyncio
import logging
import os
import subprocess

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from bot import run_bot
from cp3_diagnostics import get_cp3_stack_info

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("pipecat.communiq.server")

NODE_BACKEND_URL     = os.getenv("NODE_BACKEND_URL", "http://localhost:3000").rstrip("/")
PIPECAT_WEBHOOK_SECRET = os.getenv("PIPECAT_WEBHOOK_SECRET", "")

app = FastAPI(
    title="CommuniQ Pipecat Worker",
    version="1.0.0",
    description="Spawns one Pipecat pipeline per live voice session.",
)

# Track active agent tasks so we can cancel them if needed.
_active_agents: dict[str, asyncio.Task] = {}


# ─── Crash notification ───────────────────────────────────────────────────────

async def _notify_node_crash(session_id: str, reason: str) -> None:
    """
    Notify the Node backend that a Pipecat bot exited unexpectedly.
    Node will mark the session as 'abandoned' and clean up the LiveKit room
    so it doesn't remain stuck in 'in_progress' forever.
    """
    url = f"{NODE_BACKEND_URL}/sessions/internal/bot-crash"
    payload = {"sessionId": session_id, "reason": reason}
    headers = {"X-Communiq-Worker-Secret": PIPECAT_WEBHOOK_SECRET}

    for attempt in range(1, 4):
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code in (200, 201):
                logger.info("[%s] Node notified of bot crash.", session_id)
                return
            if 400 <= resp.status_code < 500:
                logger.warning(
                    "[%s] bot-crash POST returned %d (not retrying): %s",
                    session_id, resp.status_code, resp.text[:200],
                )
                return
            logger.warning(
                "[%s] bot-crash POST returned %d (attempt %d/3)",
                session_id, resp.status_code, attempt,
            )
        except Exception as exc:
            logger.warning(
                "[%s] bot-crash network error (attempt %d/3): %s",
                session_id, attempt, exc,
            )
        if attempt < 3:
            await asyncio.sleep(2.0 * attempt)

    logger.error("[%s] Failed to notify Node of bot crash after 3 attempts.", session_id)


def _handle_agent_done(task: asyncio.Task, session_id: str) -> None:
    """
    asyncio task done-callback.

    - Removes the session from _active_agents.
    - If the task raised an unexpected exception (not a clean cancellation),
      schedules a Node notification so the session is not left in_progress.
    """
    _active_agents.pop(session_id, None)

    if task.cancelled():
        logger.info("[%s] Agent task was cancelled (clean stop).", session_id)
        return

    exc = task.exception()
    if exc is not None:
        logger.error(
            "[%s] Agent task raised an unexpected exception: %s",
            session_id, exc,
        )
        # Schedule crash notification on the running event loop.
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(
                _notify_node_crash(session_id, str(exc)),
                name=f"crash-notify-{session_id}",
            )
        except RuntimeError:
            logger.error(
                "[%s] Could not schedule crash notification — no running loop.",
                session_id,
            )


class StartAgentRequest(BaseModel):
    session_id: str
    livekit_url: str
    agent_token: str
    system_prompt: str
    opening_text: str = ""  # The opening AI line already spoken to the user


class StopAgentRequest(BaseModel):
    session_id: str


@app.post("/start-agent")
async def start_agent(body: StartAgentRequest):
    """
    Spawn a Pipecat agent for the given session.
    If an agent is already running for this session, returns 409.
    """
    if body.session_id in _active_agents and not _active_agents[body.session_id].done():
        raise HTTPException(
            status_code=409,
            detail=f"Agent already running for session {body.session_id}",
        )

    logger.info("Starting agent — session=%s", body.session_id)

    task = asyncio.create_task(
        run_bot(
            session_id=body.session_id,
            livekit_url=body.livekit_url,
            agent_token=body.agent_token,
            system_prompt=body.system_prompt,
            opening_text=body.opening_text,
        ),
        name=f"agent-{body.session_id}",
    )
    _active_agents[body.session_id] = task

    # On task completion: clean up dict + notify Node if the bot crashed.
    task.add_done_callback(
        lambda t, sid=body.session_id: _handle_agent_done(t, sid)
    )

    return {"status": "started", "session_id": body.session_id}


@app.post("/stop-agent")
async def stop_agent(body: StopAgentRequest):
    """
    Cancel the Pipecat agent for the given session.
    Called by Node on endSession if needed (LiveKit room deletion usually
    triggers the agent to stop on its own via the on_participant_left handler).
    """
    task = _active_agents.get(body.session_id)
    if not task or task.done():
        return {"status": "not_running", "session_id": body.session_id}

    task.cancel()
    logger.info("Agent cancelled — session=%s", body.session_id)
    return {"status": "stopped", "session_id": body.session_id}


def _nvidia_gpu_line() -> str | None:
    """One-line VRAM summary for CP3 dev checks; None if nvidia-smi missing."""
    try:
        proc = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return None
        parts = proc.stdout.strip().split(",")
        if len(parts) >= 2:
            return f"{parts[0].strip()} / {parts[1].strip()} MiB"
        return proc.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


@app.get("/health")
async def health():
    """Returns worker status, active agents, optional GPU VRAM, and CP3 stack versions."""
    active = [sid for sid, t in _active_agents.items() if not t.done()]
    return {
        "status": "ok",
        "active_sessions": len(active),
        "session_ids": active,
        "whisper_device": os.getenv("WHISPER_DEVICE", "cuda"),
        "whisper_model": os.getenv("WHISPER_MODEL", "small"),
        "whisper_compute_type": os.getenv("WHISPER_COMPUTE_TYPE", "int8"),
        "llm_base_url": os.getenv("LLM_BASE_URL", "http://localhost:11434/v1"),
        "llm_model": os.getenv("LLM_MODEL", ""),
        "kokoro_voice": os.getenv("KOKORO_VOICE", "af_heart"),
        "nvidia_smi_memory_mib": _nvidia_gpu_line(),
        "cp3_stack": get_cp3_stack_info(),
        "firestore_sync_enabled": bool(
            (os.getenv("NODE_INTERNAL_URL") or "").strip()
            and len((os.getenv("PIPECAT_WEBHOOK_SECRET") or "").strip()) >= 16
        ),
    }
