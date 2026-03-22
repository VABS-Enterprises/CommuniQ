import logging

from fastapi import APIRouter, HTTPException, Request, Response

from app.schemas.tts import TTSRequest
from app.services.tts import synthesize_full, validate_voice

logger = logging.getLogger("communiq")

router = APIRouter()


@router.post("/tts")
async def tts(req: TTSRequest):
    """
    Synthesise text to MP3 audio.
    Utility endpoint — used for standalone TTS needs and manual testing.
    Returns raw audio/mpeg bytes.
    """
    resolved_voice = validate_voice(req.voice)
    try:
        audio_bytes = await synthesize_full(req.text, resolved_voice)
    except RuntimeError as e:
        logger.error("TTS failed: %s", e)
        raise HTTPException(status_code=502, detail=str(e))

    return Response(content=audio_bytes, media_type="audio/mpeg")


@router.get("/health")
async def health(request: Request):
    """Returns server status and Groq client readiness."""
    groq_ready = (
        hasattr(request.app.state, "groq_client")
        and request.app.state.groq_client is not None
    )
    return {
        "status": "ok",
        "groq_ready": groq_ready,
        "model": "llama-3.1-8b-instant",
    }
