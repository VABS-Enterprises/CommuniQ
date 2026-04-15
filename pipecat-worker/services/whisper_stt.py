"""
Local speech-to-text using faster-whisper inside Pipecat.

Uses SegmentedSTTService so VAD segments (from LiveKitTransport + Silero)
are written to WAV bytes and transcribed once per utterance.
"""

from __future__ import annotations

import asyncio
import logging
import os
import tempfile
import time
from collections.abc import AsyncGenerator
from datetime import datetime, timezone
from typing import Optional

from pipecat.frames.frames import ErrorFrame, Frame, TranscriptionFrame
from pipecat.services.stt_service import SegmentedSTTService

logger = logging.getLogger("communiq.pipecat.whisper")


class FasterWhisperSTTService(SegmentedSTTService):
    """Pipecat STT that runs faster-whisper on each VAD-finalized WAV segment."""

    def __init__(
        self,
        *,
        model: str = "small",
        device: str = "cuda",
        compute_type: str = "int8",
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._model_name = model
        self._device = device
        self._compute_type = compute_type
        self._model: Optional[object] = None

    def _get_model(self):
        if self._model is None:
            from faster_whisper import WhisperModel  # noqa: PLC0415

            logger.info(
                "Loading faster-whisper model=%s device=%s compute_type=%s",
                self._model_name,
                self._device,
                self._compute_type,
            )
            self._model = WhisperModel(
                self._model_name,
                device=self._device,
                compute_type=self._compute_type,
            )
            logger.info("faster-whisper ready.")
        return self._model

    def _transcribe_wav_bytes_sync(self, wav_bytes: bytes) -> str:
        """Blocking: WAV (with header) -> transcript text."""
        if len(wav_bytes) < 500:
            return ""

        model = self._get_model()
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp.write(wav_bytes)
                tmp_path = tmp.name

            t0 = time.perf_counter()
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
            wall_ms = (time.perf_counter() - t0) * 1000.0
            logger.info(
                "Local ASR: %.1fs audio -> %d chars (wall_ms=%.0f)",
                getattr(info, "duration", 0.0) or 0.0,
                len(text),
                wall_ms,
            )
            return text
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)

    async def run_stt(self, audio: bytes) -> AsyncGenerator[Frame, None]:
        try:
            text = await asyncio.to_thread(self._transcribe_wav_bytes_sync, audio)
            if text:
                ts = datetime.now(timezone.utc).isoformat()
                # user_id is populated by SegmentedSTTService from incoming audio frames
                uid = getattr(self, "_user_id", "") or ""
                yield TranscriptionFrame(text=text, user_id=uid, timestamp=ts)
        except Exception as exc:  # noqa: BLE001
            logger.exception("faster-whisper transcription failed")
            yield ErrorFrame(error=f"faster-whisper: {exc}", fatal=False)
