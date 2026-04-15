"""
Text-to-speech entry point. TTS_BACKEND selects the engine (default: groq).

  groq  — Groq PlayAI cloud TTS (~1 s latency, requires GROQ_API_KEY)
  edge  — Microsoft Edge TTS (free, ~10-18 s latency, no key needed)
  local — Kokoro CPU TTS (offline, requires kokoro + ffmpeg installed)
"""

import asyncio
import io
import logging
import os

from app.config import settings
from app.services import tts as edge_tts

logger = logging.getLogger("communiq")

# Lazy-loaded Kokoro pipeline — CPU only, loaded on first local TTS request.
_kokoro_pipeline = None

# canopylabs/orpheus-v1-english replaced playai-tts (decommissioned 2025-12-31).
# Orpheus constraints: response_format must be "wav", max input = 200 chars per request.
_GROQ_TTS_MODEL = "canopylabs/orpheus-v1-english"
_GROQ_TTS_VOICE = "troy"   # male voice; others: autumn, diana, hannah, austin, daniel
_GROQ_TTS_MAX_CHARS = 195  # stay under the 200-char hard limit with a small margin


def _get_kokoro():
    global _kokoro_pipeline
    if _kokoro_pipeline is None:
        from kokoro import KPipeline  # noqa: PLC0415
        logger.info("Loading Kokoro TTS pipeline (CPU)...")
        _kokoro_pipeline = KPipeline(lang_code="a")  # "a" = American English
        logger.info("Kokoro TTS pipeline ready.")
    return _kokoro_pipeline


def _split_for_orpheus(text: str) -> list[str]:
    """
    Split text into chunks of at most _GROQ_TTS_MAX_CHARS characters.

    Strategy: split on sentence-ending punctuation first, then on commas,
    then hard-cut at the char limit as a last resort.
    """
    import re
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    chunks: list[str] = []
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        if len(sentence) <= _GROQ_TTS_MAX_CHARS:
            chunks.append(sentence)
        else:
            # Split long sentence on commas
            parts = [p.strip() for p in sentence.split(",") if p.strip()]
            current = ""
            for part in parts:
                candidate = (current + ", " + part).strip(", ") if current else part
                if len(candidate) <= _GROQ_TTS_MAX_CHARS:
                    current = candidate
                else:
                    if current:
                        chunks.append(current)
                    # Hard-cut if a single comma-part is still too long
                    while len(part) > _GROQ_TTS_MAX_CHARS:
                        chunks.append(part[:_GROQ_TTS_MAX_CHARS])
                        part = part[_GROQ_TTS_MAX_CHARS:]
                    current = part
            if current:
                chunks.append(current)
    return [c for c in chunks if c]


def _concat_wav(wav_chunks: list[bytes]) -> bytes:
    """Merge a list of WAV byte buffers into a single WAV file."""
    import io
    import wave
    if not wav_chunks:
        return b""
    if len(wav_chunks) == 1:
        return wav_chunks[0]
    pcm_frames: list[bytes] = []
    nchannels = sampwidth = framerate = None
    for chunk in wav_chunks:
        with wave.open(io.BytesIO(chunk), "rb") as wf:
            if nchannels is None:
                nchannels = wf.getnchannels()
                sampwidth = wf.getsampwidth()
                framerate = wf.getframerate()
            pcm_frames.append(wf.readframes(wf.getnframes()))
    out = io.BytesIO()
    with wave.open(out, "wb") as wf:
        # Set each parameter individually — avoids copying nframes from the
        # source file which causes struct overflow when writing the header.
        wf.setnchannels(nchannels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(framerate)
        for pcm in pcm_frames:
            wf.writeframes(pcm)
    out.seek(0)
    return out.read()


async def _call_groq_tts_chunk(chunk: str, api_key: str) -> bytes:
    """POST one ≤195-char chunk to Groq Orpheus TTS; returns WAV bytes."""
    import httpx
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/audio/speech",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": _GROQ_TTS_MODEL,
                "voice": _GROQ_TTS_VOICE,
                "input": chunk,
                "response_format": "wav",
            },
        )
        if not resp.is_success:
            err_body = resp.text[:300]
            raise RuntimeError(
                f"Groq TTS returned {resp.status_code}: {err_body}"
            )
        return resp.content


async def _synthesize_groq(text: str) -> bytes:
    """
    Synthesize text to WAV bytes using Groq Orpheus TTS.

    Splits the text into ≤195-char chunks (API hard limit = 200),
    calls the API for each chunk, then concatenates the WAV results.
    """
    from app.services.tts import strip_stage_directions
    text = strip_stage_directions(text)
    if not text:
        return b""
    api_key = os.getenv("GROQ_API_KEY", "")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY is required for TTS_BACKEND=groq.")
    chunks = _split_for_orpheus(text)
    wav_chunks = []
    for chunk in chunks:
        wav = await _call_groq_tts_chunk(chunk, api_key)
        if wav:
            wav_chunks.append(wav)
    return _concat_wav(wav_chunks)


async def synthesize_full(text: str, voice: str | None = None) -> bytes:
    if settings.tts_backend == "groq":
        return await _synthesize_groq(text)
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
