import asyncio
import io
import re

import edge_tts

DEFAULT_VOICE = "en-IN-PrabhatNeural"  # matches pipecat-worker voice — same AI voice throughout

# Strips AI parenthesis stage-directions like (nervously), (pauses).
# Square-bracket [directions] are intentionally kept because Orpheus TTS uses
# them as vocal direction controls (e.g. [cheerful], [whisper]).
_STAGE_DIRECTION = re.compile(r"\s*[（(][^)）]{1,60}[)）]\s*")

# Supported Indian English + fallback voices.
SUPPORTED_VOICES = {
    "en-IN-NeerjaNeural",   # female, Indian English (default)
    "en-IN-PrabhatNeural",  # male, Indian English
    "en-US-JennyNeural",    # female, US English (fallback)
    "en-GB-SoniaNeural",    # female, British English (fallback)
}

_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
_MIN_CHUNK_CHARS = 20


def validate_voice(voice_id: str | None) -> str:
    """Return voice_id if valid, otherwise fall back to the default voice."""
    if voice_id and voice_id.strip() in SUPPORTED_VOICES:
        return voice_id.strip()
    return DEFAULT_VOICE


def split_sentences(text: str) -> list[str]:
    """
    Split text into TTS-ready chunks.

    1. Split on sentence-ending punctuation (. ! ?)
    2. For long comma-separated clauses (>45 chars), split at commas —
       but merge pieces shorter than _MIN_CHUNK_CHARS to avoid choppy audio.
    3. Drop empty chunks.
    """
    raw = _SENTENCE_END.split(text.strip())
    result: list[str] = []

    for chunk in raw:
        chunk = chunk.strip()
        if not chunk:
            continue

        if len(chunk) > 45 and "," in chunk:
            parts = [p.strip() for p in chunk.split(",") if p.strip()]
            merged: list[str] = []
            carry = ""
            for part in parts:
                combined = (carry + " " + part).strip() if carry else part
                if len(combined) >= _MIN_CHUNK_CHARS:
                    merged.append(combined)
                    carry = ""
                else:
                    carry = combined
            if carry:
                if merged:
                    merged[-1] = merged[-1] + ", " + carry
                else:
                    merged.append(carry)
            result.extend(merged)
        else:
            result.append(chunk)

    return result


async def synthesize_sentence(text: str, voice: str | None = None) -> bytes:
    """
    Synthesize a single sentence or clause to MP3 bytes.
    Retries once on transient network failure.
    Returns b"" for blank input.
    """
    text = text.strip()
    if not text:
        return b""

    resolved_voice = validate_voice(voice)

    try:
        return await _call_edge_tts(text, resolved_voice)
    except Exception:
        await asyncio.sleep(0.3)
        try:
            return await _call_edge_tts(text, resolved_voice)
        except Exception as err:
            raise RuntimeError(
                f"edge-tts failed after 2 attempts for voice '{resolved_voice}': {err}"
            ) from err


def strip_stage_directions(text: str) -> str:
    """Remove parenthesised/bracketed stage directions before TTS synthesis."""
    return _STAGE_DIRECTION.sub(" ", text).strip()


async def synthesize_full(text: str, voice: str | None = None) -> bytes:
    """
    Synthesize a full text block to a single concatenated MP3.
    Used by /tts and /session/turn endpoints.
    """
    text = strip_stage_directions(text)
    sentences = split_sentences(text)
    if not sentences:
        return b""

    chunks = []
    for sentence in sentences:
        chunk = await synthesize_sentence(sentence, voice)
        if chunk:
            chunks.append(chunk)

    return b"".join(chunks)


async def _call_edge_tts(text: str, voice: str) -> bytes:
    communicate = edge_tts.Communicate(text=text, voice=voice)
    buffer = io.BytesIO()
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            buffer.write(chunk["data"])
    audio = buffer.getvalue()
    if not audio:
        raise RuntimeError(f"edge-tts returned empty audio for voice '{voice}'.")
    return audio
