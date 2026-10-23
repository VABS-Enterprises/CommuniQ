import asyncio
import io
import re
from typing import AsyncIterator

import edge_tts

DEFAULT_VOICE = "en-IN-PrabhatNeural"  # matches pipecat-worker voice — same AI voice throughout

# Strips AI parenthesis stage-directions like (nervously), (pauses).
# Square-bracket [directions] are intentionally kept because Orpheus TTS uses
# them as vocal direction controls (e.g. [cheerful], [whisper]).
_STAGE_DIRECTION = re.compile(r"\s*[（(][^)）]{1,60}[)）]\s*")

# Models write roleplay actions as *smiles warmly* and emphasis as **important**.
# Neither is speech, and every TTS backend pronounces the character: listeners
# heard "asterisk smiles warmly asterisk". Actions are dropped like their
# parenthesised equivalents above; emphasis keeps its words and loses only the
# markers. The length bound is the same 60 characters, so a lone `*` in prose
# and a multi-sentence span are both left alone.
_MD_BOLD = re.compile(r"\*\*(.+?)\*\*|__(.+?)__", re.DOTALL)
_MD_ACTION = re.compile(r"\s*\*([^*\n]{1,60})\*\s*")
_MD_HEADING = re.compile(r"^\s{0,3}#{1,6}\s*", re.MULTILINE)
_MD_BULLET = re.compile(r"^\s{0,3}[-*+]\s+", re.MULTILINE)
_MD_CODE = re.compile(r"`+")
_EXTRA_SPACE = re.compile(r"[ \t]{2,}")

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
    """
    Strip everything that is written for the eye, not the ear, before synthesis:
    parenthesised stage directions and Markdown that the voice would otherwise
    read out character by character.
    """
    text = _STAGE_DIRECTION.sub(" ", text)
    text = _MD_BOLD.sub(lambda m: m.group(1) or m.group(2) or "", text)
    text = _MD_ACTION.sub(" ", text)
    text = _MD_HEADING.sub("", text)
    text = _MD_BULLET.sub("", text)
    text = _MD_CODE.sub("", text)
    return _EXTRA_SPACE.sub(" ", text).strip()


# edge-tts is a network round trip per chunk, so several can be in flight at
# once. Bounded because a long reply would otherwise open a dozen sockets to
# the same free service in one burst.
_MAX_CONCURRENT_TTS = 4


async def synthesize_stream(
    text: str, voice: str | None = None
) -> AsyncIterator[tuple[int, bytes]]:
    """
    Yield `(index, mp3_bytes)` per sentence, **in order**, as each is ready.

    This is what makes a reply start playing immediately. Synthesis used to be
    a sequential loop whose caller waited for the whole block: a mid-length
    answer took 5.7s before a single byte of audio existed, which was ~92% of
    the perceived turn latency.

    Every sentence is dispatched at once (up to [_MAX_CONCURRENT_TTS]) so the
    later ones are already being synthesised while the first is being sent.
    Results are yielded strictly in order — audio has to play in the order it
    was written, so out-of-order completion cannot be forwarded.
    """
    text = strip_stage_directions(text)
    sentences = split_sentences(text)
    if not sentences:
        return

    semaphore = asyncio.Semaphore(_MAX_CONCURRENT_TTS)

    async def run(sentence: str) -> bytes:
        async with semaphore:
            return await synthesize_sentence(sentence, voice)

    tasks = [asyncio.create_task(run(s)) for s in sentences]
    try:
        for index, task in enumerate(tasks):
            chunk = await task
            if chunk:
                yield index, chunk
    finally:
        # A disconnected client must not leave synthesis running.
        for task in tasks:
            if not task.done():
                task.cancel()


async def synthesize_full(text: str, voice: str | None = None) -> bytes:
    """
    Synthesize a full text block to a single concatenated MP3.
    Used by /tts and the non-streaming /session/turn.

    Shares [synthesize_stream]'s concurrency, so even callers that need the
    whole blob no longer pay for one sequential round trip per sentence.
    """
    chunks = [chunk async for _, chunk in synthesize_stream(text, voice)]
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
