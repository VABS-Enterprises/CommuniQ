"""
Local text-to-speech using Kokoro inside Pipecat.

Yields 16-bit mono PCM at 24 kHz as TTSAudioRawFrame chunks for LiveKit output.
"""

from __future__ import annotations

import asyncio
import logging
import re
import time
from collections.abc import AsyncGenerator
from typing import Optional

import numpy as np
from pipecat.frames.frames import Frame, TTSAudioRawFrame
from pipecat.services.tts_service import TTSService

logger = logging.getLogger("communiq.pipecat.kokoro")

# Kokoro outputs 24 kHz float32; chunk size ~100 ms for smoother streaming
_CHUNK_SAMPLES = 2400  # 100 ms at 24 kHz mono int16

# Written for the eye, not the ear. The model narrates actions as *smiles* and
# emphasises with **bold**; spoken verbatim that becomes "asterisk smiles
# asterisk". Mirrors ai-server/app/services/tts.py:strip_stage_directions so
# both voice paths sound the same.
_STAGE_DIRECTION = re.compile(r"\s*[（(][^)）]{1,60}[)）]\s*")
_MD_BOLD = re.compile(r"\*\*(.+?)\*\*|__(.+?)__", re.DOTALL)
_MD_ACTION = re.compile(r"\s*\*([^*\n]{1,60})\*\s*")
_MD_HEADING = re.compile(r"^\s{0,3}#{1,6}\s*", re.MULTILINE)
_MD_BULLET = re.compile(r"^\s{0,3}[-*+]\s+", re.MULTILINE)
_MD_CODE = re.compile(r"`+")
_EXTRA_SPACE = re.compile(r"[ \t]{2,}")


def strip_unspoken_markup(text: str) -> str:
    """Drop stage directions and Markdown so the voice reads words only."""
    text = _STAGE_DIRECTION.sub(" ", text)
    text = _MD_BOLD.sub(lambda m: m.group(1) or m.group(2) or "", text)
    text = _MD_ACTION.sub(" ", text)
    text = _MD_HEADING.sub("", text)
    text = _MD_BULLET.sub("", text)
    text = _MD_CODE.sub("", text)
    return _EXTRA_SPACE.sub(" ", text).strip()


class KokoroTTSService(TTSService):
    """Pipecat TTS using Kokoro KPipeline (CPU)."""

    def __init__(
        self,
        *,
        voice: str = "af_heart",
        **kwargs,
    ) -> None:
        super().__init__(
            sample_rate=24000,
            push_text_frames=True,
            push_stop_frames=True,
            push_start_frame=True,
            **kwargs,
        )
        self._voice = voice
        self._pipeline: Optional[object] = None

    def _get_pipeline(self):
        if self._pipeline is None:
            from kokoro import KPipeline  # noqa: PLC0415

            logger.info("Loading Kokoro KPipeline (lang_code=a)...")
            self._pipeline = KPipeline(lang_code="a")
            logger.info("Kokoro ready.")
        return self._pipeline

    def _synthesize_pcm_int16_sync(self, text: str) -> bytes:
        """Blocking: full utterance text -> int16 mono PCM bytes at 24 kHz."""
        pipeline = self._get_pipeline()
        chunks: list[np.ndarray] = []
        t0 = time.perf_counter()
        for _g, _p, audio in pipeline(text, voice=self._voice, speed=1.0):
            if audio is not None and len(audio) > 0:
                chunks.append(audio)
        if not chunks:
            return b""
        combined = np.concatenate(chunks, axis=0)
        pcm = (np.clip(combined, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes()
        wall_ms = (time.perf_counter() - t0) * 1000.0
        logger.info(
            "Kokoro TTS: %d chars -> %d KB PCM (wall_ms=%.0f)",
            len(text),
            len(pcm) // 1024,
            wall_ms,
        )
        return pcm

    async def run_tts(
        self, text: str, context_id: str
    ) -> AsyncGenerator[Frame, None]:
        prepared = self._prepare_text_for_tts(strip_unspoken_markup(text))
        if not prepared.strip():
            return

        pcm = await asyncio.to_thread(self._synthesize_pcm_int16_sync, prepared)
        if not pcm:
            return

        chunk_bytes = _CHUNK_SAMPLES * 2
        for i in range(0, len(pcm), chunk_bytes):
            chunk = pcm[i : i + chunk_bytes]
            if not chunk:
                continue
            yield TTSAudioRawFrame(
                audio=chunk,
                sample_rate=self.sample_rate,
                num_channels=1,
                context_id=context_id,
            )
