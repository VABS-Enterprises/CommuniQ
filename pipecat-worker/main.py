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

app = FastAPI(
    title="CommuniQ Pipecat Worker",
    version="1.0.0",
    description="Spawns one Pipecat pipeline per live voice session.",
)

# Track active agent tasks so we can cancel them if needed.
_active_agents: dict[str, asyncio.Task] = {}


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

    # Clean up the dict when the task finishes to avoid unbounded growth.
    task.add_done_callback(
        lambda t: _active_agents.pop(body.session_id, None)
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
