"""
Text-to-speech entry point. TTS_BACKEND selects the engine (default: edge).
"""

import asyncio
import io
import logging

from app.config import settings
from app.services import tts as edge_tts

logger = logging.getLogger("communiq")

# Lazy-loaded Kokoro pipeline — CPU only, loaded on first local TTS request.
_kokoro_pipeline = None


def _get_kokoro():
    global _kokoro_pipeline
    if _kokoro_pipeline is None:
        from kokoro import KPipeline  # noqa: PLC0415
        logger.info("Loading Kokoro TTS pipeline (CPU)...")
        _kokoro_pipeline = KPipeline(lang_code="a")  # "a" = American English
        logger.info("Kokoro TTS pipeline ready.")
    return _kokoro_pipeline


async def synthesize_full(text: str, voice: str | None = None) -> bytes:
    if settings.tts_backend == "edge":
        return await edge_tts.synthesize_full(text, voice)
    if settings.tts_backend == "local":
        # Kokoro is synchronous (CPU); run in a thread to keep the event loop free.
        return await asyncio.to_thread(_synthesize_kokoro, text)
    raise ValueError(f"Unknown TTS_BACKEND: {settings.tts_backend!r}")


def _synthesize_kokoro(text: str) -> bytes:
    """
    Synthesise text to MP3 bytes using local Kokoro TTS (blocking, run via to_thread).

    Pipeline:
      text → Kokoro (yields float32 audio arrays at 24 kHz)
           → concatenate → write WAV to buffer
           → pydub AudioSegment → export as MP3 bytes

    Flutter already decodes base64 MP3, so the output format matches what
    Edge-TTS returns. No client-side changes needed.
    """
    import numpy as np
    import soundfile as sf
    from pydub import AudioSegment

    if not text or not text.strip():
        return b""

    pipeline = _get_kokoro()
    voice_id = settings.kokoro_voice
    sample_rate = 24000  # Kokoro always outputs 24 kHz

    audio_chunks = []
    for _graphemes, _phonemes, audio in pipeline(text, voice=voice_id, speed=1.0):
        if audio is not None and len(audio) > 0:
            audio_chunks.append(audio)

    if not audio_chunks:
        raise RuntimeError(
            f"Kokoro returned no audio for the given text (voice={voice_id!r})."
        )

    combined = np.concatenate(audio_chunks, axis=0)

    # Write 24kHz float32 audio to an in-memory WAV buffer.
    wav_buffer = io.BytesIO()
    sf.write(wav_buffer, combined, sample_rate, format="WAV", subtype="PCM_16")
    wav_buffer.seek(0)

    # Convert WAV → MP3 via pydub (requires ffmpeg on PATH).
    segment = AudioSegment.from_wav(wav_buffer)
    mp3_buffer = io.BytesIO()
    segment.export(mp3_buffer, format="mp3", bitrate="128k")

    mp3_bytes = mp3_buffer.getvalue()
    logger.info(
        "Local TTS: %d chars → %d KB MP3 (voice=%s)",
        len(text),
        len(mp3_bytes) // 1024,
        voice_id,
    )
    return mp3_bytes
