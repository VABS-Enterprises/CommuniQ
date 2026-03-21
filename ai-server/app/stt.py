import io
import os

from groq import AsyncGroq

_client: AsyncGroq | None = None

MAX_AUDIO_BYTES = 25 * 1024 * 1024   # 25 MB — Groq's hard limit
MIN_AUDIO_BYTES = 1024                 # 1 KB  — anything smaller is not real audio

# Whisper prompt nudges transcription toward Indian English patterns and
# common vocabulary used in interview/GD/sales contexts.
_WHISPER_PROMPT = (
    "This is a spoken English conversation between an Indian professional or student "
    "and an AI interviewer. The speaker may use Indian English pronunciation and occasional "
    "Hinglish words. Common topics: work experience, projects, challenges, teamwork, "
    "sales, group discussions. Transcribe accurately including filler words like um, uh, like."
)


def _get_client() -> AsyncGroq:
    global _client
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError(
                "GROQ_API_KEY is not set. Add it to ai-server/.env and restart the server."
            )
        _client = AsyncGroq(api_key=api_key)
    return _client


async def transcribe(audio_bytes: bytes, filename: str = "audio.m4a") -> str:
    """
    Transcribe audio bytes to text using Groq Whisper Large V3.

    Args:
        audio_bytes: Raw audio file bytes.
        filename:    Original filename — used to determine audio format (m4a, wav, webm, etc.)

    Returns:
        Transcript as a plain string with leading/trailing whitespace stripped.

    Raises:
        ValueError:  If audio is empty, too small, or exceeds the size limit.
        RuntimeError: If the Groq API call fails.
    """
    if not audio_bytes:
        raise ValueError("Audio data is empty.")

    if len(audio_bytes) < MIN_AUDIO_BYTES:
        raise ValueError(
            f"Audio file is too small ({len(audio_bytes)} bytes). "
            "The recording may be too short or corrupted."
        )

    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise ValueError(
            f"Audio file is too large ({len(audio_bytes) / 1024 / 1024:.1f} MB). "
            f"Maximum allowed size is {MAX_AUDIO_BYTES // 1024 // 1024} MB."
        )

    client = _get_client()
    audio_file = (filename, io.BytesIO(audio_bytes), _mime_type(filename))

    try:
        transcription = await client.audio.transcriptions.create(
            model="whisper-large-v3",
            file=audio_file,
            response_format="text",
            language="en",
            prompt=_WHISPER_PROMPT,
        )
    except Exception as e:
        raise RuntimeError(f"Groq Whisper transcription failed: {e}") from e

    text = transcription if isinstance(transcription, str) else transcription.text
    text = text.strip()

    if not text:
        raise ValueError(
            "Whisper returned an empty transcript. "
            "The audio may contain no speech or be too noisy."
        )

    return text


def _mime_type(filename: str) -> str:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return {
        "m4a":  "audio/mp4",
        "mp4":  "audio/mp4",
        "mp3":  "audio/mpeg",
        "wav":  "audio/wav",
        "webm": "audio/webm",
        "ogg":  "audio/ogg",
        "flac": "audio/flac",
        "aac":  "audio/aac",
    }.get(ext, "audio/mp4")
