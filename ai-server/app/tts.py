import asyncio
import io
import re

import edge_tts

DEFAULT_VOICE = "en-IN-NeerjaNeural"

# All supported Indian English + fallback voices.
# Passed as voice_id from the Flutter template — validated here before calling edge-tts.
SUPPORTED_VOICES = {
    "en-IN-NeerjaNeural",   # female, Indian English (default)
    "en-IN-PrabhatNeural",  # male, Indian English
    "en-IN-AaravNeural",    # male, Indian English (alternate)
    "en-US-JennyNeural",    # female, US English (fallback for non-Indian voices)
    "en-GB-SoniaNeural",    # female, British English (fallback)
}

_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
_MIN_CHUNK_CHARS = 20    # don't synthesize chunks shorter than this — avoids choppy single-word audio
WORD_COUNT_FLUSH_THRESHOLD = 15   # synthesize buffer if LLM generates this many words with no punctuation


def validate_voice(voice_id: str | None) -> str:
    """Return voice_id if valid, otherwise fall back to the default voice."""
    if voice_id and voice_id.strip() in SUPPORTED_VOICES:
        return voice_id.strip()
    return DEFAULT_VOICE


def split_sentences(text: str) -> list[str]:
    """
    Split text into TTS-ready chunks for sentence-level streaming.

    Strategy:
    1. Split on sentence-ending punctuation (. ! ?)
    2. For long comma-separated clauses (>45 chars), split at commas to get
       audio to the client faster — but merge pieces shorter than _MIN_CHUNK_CHARS
       to avoid single-word synthesis.
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


def should_flush_buffer(buffer: str) -> bool:
    """
    True when the LLM token buffer is long enough to synthesize even without
    sentence-ending punctuation — prevents silent gaps on responses that use
    dashes, colons, or no punctuation at all.
    """
    return len(buffer.strip().split()) >= WORD_COUNT_FLUSH_THRESHOLD


async def synthesize_sentence(text: str, voice: str | None = None) -> bytes:
    """
    Synthesize a single sentence or clause to MP3 bytes.
    Retries once on network failure before raising.
    Returns b"" for blank input.
    """
    text = text.strip()
    if not text:
        return b""

    resolved_voice = validate_voice(voice)

    try:
        return await _call_edge_tts(text, resolved_voice)
    except Exception as first_err:
        # One retry after a short delay — edge-tts occasionally has transient failures
        await asyncio.sleep(0.3)
        try:
            return await _call_edge_tts(text, resolved_voice)
        except Exception as second_err:
            raise RuntimeError(
                f"edge-tts failed after 2 attempts for voice '{resolved_voice}': {second_err}"
            ) from second_err


async def synthesize_full(text: str, voice: str | None = None) -> bytes:
    """
    Synthesize a full text block to a single concatenated MP3.
    Used by the /tts utility endpoint.
    """
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
