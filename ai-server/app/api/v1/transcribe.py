from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from groq import AsyncGroq

from app.dependencies import get_groq_client, verify_internal_api_key
from app.services import stt

router = APIRouter(dependencies=[Depends(verify_internal_api_key)])


@router.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    groq_client: AsyncGroq = Depends(get_groq_client),
):
    """
    Transcribe an uploaded audio file to text using Groq Whisper.

    Accepts any format supported by Groq (wav, mp3, m4a, webm, ogg, flac, aac).
    Returns: { "text": "<transcript>" }
    """
    audio_bytes = await file.read()
    filename = file.filename or "audio.wav"

    try:
        text = await stt.transcribe(audio_bytes, filename, groq_client)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return {"text": text}
