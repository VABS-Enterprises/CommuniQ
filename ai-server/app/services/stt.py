import io

from groq import AsyncGroq

MAX_AUDIO_BYTES = 25 * 1024 * 1024   # 25 MB — Groq's hard limit
MIN_AUDIO_BYTES = 1024                 # 1 KB  — anything smaller is not real audio

# Nudges Whisper toward Indian English and common CommuniQ vocabulary.
_WHISPER_PROMPT = (
    "This is a spoken English conversation between an Indian professional or student "
    "and an AI interviewer. The speaker may use Indian English pronunciation and occasional "
    "Hinglish words. Common topics: work experience, projects, challenges, teamwork, "
    "sales, group discussions. Transcribe accurately including filler words like um, uh, like."
)


async def transcribe(
    audio_bytes: bytes,
    filename: str = "audio.wav",
    client: AsyncGroq = None,
) -> str:
    """
    Transcribe audio bytes to text using Groq Whisper Large V3.

    Args:
        audio_bytes: Raw audio file bytes.
        filename:    Original filename — used to determine audio format.
        client:      Shared AsyncGroq instance (injected by the route handler).

    Returns:
        Transcript as a plain string with whitespace stripped.

    Raises:
        ValueError:   If audio is empty, too small, or exceeds the size limit.
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

    if client is None:
        raise RuntimeError("Groq client is required for transcription.")

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
