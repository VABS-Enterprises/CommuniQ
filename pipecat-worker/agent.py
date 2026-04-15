"""
CommuniQ Pipecat agent — live voice pipeline (local models).

Pipeline per session:
  LiveKit mic audio
    → Silero VAD (end-of-speech + barge-in)
    → faster-whisper STT (per VAD segment, via SegmentedSTTService)
    → Ollama / vLLM LLM (OpenAI-compatible streaming tokens)
    → Kokoro TTS (sentence-chunked PCM at 24 kHz)
    → LiveKit speaker audio

Fallback architecture (no Pipecat): Flutter → Node → FastAPI with Groq + Edge-TTS.

Barge-in: Pipecat cancels active TTS + LLM when VAD detects user speech during playback.
"""

from __future__ import annotations

import asyncio
import logging
import os

from dotenv import load_dotenv
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.openai_llm_context import OpenAILLMContext
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.transports.livekit.transport import LiveKitParams, LiveKitTransport

from services.firestore_sync import (
    LiveVoiceAssistantSyncProcessor,
    LiveVoiceUserSyncProcessor,
)
from services.kokoro_tts import KokoroTTSService
from services.whisper_stt import FasterWhisperSTTService

load_dotenv()
logger = logging.getLogger("communiq.pipecat.agent")


async def run_agent(
    session_id: str,
    livekit_url: str,
    agent_token: str,
    system_prompt: str,
) -> None:
    """
    Spin up a full Pipecat pipeline for one CommuniQ session.

    Args:
        session_id: LiveKit room name (same as Firestore session id).
        livekit_url: ws:// or wss:// URL of the LiveKit server.
        agent_token: JWT minted by Node for this agent participant.
        system_prompt: Scenario system prompt (persona + tone + level).
    """
    logger.info("Agent starting — session=%s", session_id)

    transport = LiveKitTransport(
        url=livekit_url,
        token=agent_token,
        room_name=session_id,
        params=LiveKitParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            vad_enabled=True,
            vad_analyzer=SileroVADAnalyzer(
                params=VADParams(
                    stop_secs=0.8,
                )
            ),
            vad_audio_passthrough=True,
        ),
    )

    stt = FasterWhisperSTTService(
        model=os.getenv("WHISPER_MODEL", "small"),
        device=os.getenv("WHISPER_DEVICE", "cuda"),
        compute_type=os.getenv("WHISPER_COMPUTE_TYPE", "int8"),
    )

    llm = OpenAILLMService(
        base_url=os.getenv("LLM_BASE_URL", "http://localhost:11434/v1"),
        api_key=os.getenv("OPENAI_API_KEY", "not-needed"),
        model=os.getenv("LLM_MODEL", "llama3.2:3b"),
    )

    context = OpenAILLMContext(
        messages=[{"role": "system", "content": system_prompt}]
    )
    context_aggregator = llm.create_context_aggregator(context)

    tts = KokoroTTSService(
        voice=os.getenv("KOKORO_VOICE", "af_heart"),
    )

    node_url = (os.getenv("NODE_INTERNAL_URL") or "").strip()
    webhook_secret = (os.getenv("PIPECAT_WEBHOOK_SECRET") or "").strip()
    user_sync = None
    assistant_sync = None
    if node_url and len(webhook_secret) >= 16:
        user_sync = LiveVoiceUserSyncProcessor(
            session_id=session_id,
            node_base_url=node_url,
            webhook_secret=webhook_secret,
            name="LiveVoiceUserSync",
        )
        assistant_sync = LiveVoiceAssistantSyncProcessor(
            session_id=session_id,
            node_base_url=node_url,
            webhook_secret=webhook_secret,
            name="LiveVoiceAssistantSync",
        )
        logger.info("Live-voice → Node Firestore sync enabled — %s", node_url)
    else:
        logger.warning(
            "Live-voice Firestore sync disabled — set NODE_INTERNAL_URL and "
            "PIPECAT_WEBHOOK_SECRET (>=16 chars) to match server/.env"
        )

    chain: list = [
        transport.input(),
        stt,
    ]
    if user_sync is not None:
        chain.append(user_sync)
    chain.extend(
        [
            context_aggregator.user(),
            llm,
        ]
    )
    if assistant_sync is not None:
        chain.append(assistant_sync)
    chain.extend(
        [
            tts,
            transport.output(),
            context_aggregator.assistant(),
        ]
    )

    pipeline = Pipeline(chain)

    task = PipelineTask(
        pipeline,
        params=PipelineParams(
            allow_interruptions=True,
            enable_metrics=True,
            enable_usage_logging=True,
        ),
    )

    @transport.event_handler("on_first_participant_joined")
    async def on_first_participant_joined(transport, participant):
        logger.info(
            "User joined room — session=%s participant=%s",
            session_id,
            participant["identity"],
        )
        await task.queue_frames([context_aggregator.user().get_context_frame()])

    @transport.event_handler("on_participant_left")
    async def on_participant_left(transport, participant, reason):
        logger.info("User left room — session=%s reason=%s", session_id, reason)
        await task.cancel()

    runner = PipelineRunner()
    try:
        await runner.run(task)
    except asyncio.CancelledError:
        pass
    finally:
        logger.info("Agent finished — session=%s", session_id)
