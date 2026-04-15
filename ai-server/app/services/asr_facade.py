"""
Speech-to-text entry point. ASR_BACKEND selects the implementation (default: groq).
"""

import asyncio
import logging
import os
import tempfile

from typing import Optional

from groq import AsyncGroq

from app.config import settings
from app.services import stt as groq_stt

logger = logging.getLogger("communiq")

# Lazy-loaded faster-whisper model.
# Loaded on first local transcription request, not at import time, so VRAM is
# only consumed when ASR_BACKEND=local is actually used.
_local_whisper = None


def _get_local_whisper():
    global _local_whisper
    if _local_whisper is None:
        from faster_whisper import WhisperModel  # noqa: PLC0415
        logger.info(
            "Loading faster-whisper '%s' on %s (%s) — first request only...",
            settings.whisper_model,
            settings.whisper_device,
            settings.whisper_compute_type,
        )
        _local_whisper = WhisperModel(
            settings.whisper_model,
            device=settings.whisper_device,
            compute_type=settings.whisper_compute_type,
        )
        logger.info("faster-whisper ready.")
    return _local_whisper


async def transcribe(
    audio_bytes: bytes,
    filename: str,
    groq: Optional[AsyncGroq],
) -> str:
    if settings.asr_backend == "groq":
        if groq is None:
            raise RuntimeError(
                "ASR_BACKEND=groq but Groq client is not initialised. "
                "Set GROQ_API_KEY and ensure at least one backend uses groq."
            )
        return await groq_stt.transcribe(audio_bytes, filename, groq)
    if settings.asr_backend == "local":
        # Run the blocking CTranslate2 inference in a thread so the event loop
        # stays free for other requests while Whisper is working.
        return await asyncio.to_thread(_transcribe_local, audio_bytes, filename)
    raise ValueError(f"Unknown ASR_BACKEND: {settings.asr_backend!r}")


def _transcribe_local(audio_bytes: bytes, filename: str) -> str:
    """Transcribe using faster-whisper on the local GPU (blocking, run via to_thread)."""
    if not audio_bytes:
        raise ValueError("Audio data is empty.")

    suffix = "." + filename.rsplit(".", 1)[-1] if "." in filename else ".wav"
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(audio_bytes)
            tmp_path = tmp.name

        model = _get_local_whisper()
        segments, info = model.transcribe(
            tmp_path,
            beam_size=5,
            language="en",
            initial_prompt=(
                "This is a spoken English conversation between an Indian professional "
                "or student and an AI interviewer. Transcribe accurately including "
                "filler words like um, uh, like."
            ),
        )
        text = " ".join(seg.text for seg in segments).strip()
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)

    if not text:
        raise ValueError(
            "Local Whisper returned an empty transcript. "
            "The audio may contain no speech or be too noisy."
        )

    logger.info(
        "Local ASR: %.1fs audio → %d chars (model: %s)",
        info.duration,
        len(text),
        settings.whisper_model,
    )
    return text
