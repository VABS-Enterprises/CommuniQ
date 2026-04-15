import importlib.metadata
import logging
import subprocess

import httpx
from fastapi import APIRouter, HTTPException, Request, Response

from app.config import settings
from app.schemas.tts import TTSRequest
from app.services import tts_facade
from app.services.tts import validate_voice

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
        audio_bytes = await tts_facade.synthesize_full(req.text, resolved_voice)
    except RuntimeError as e:
        logger.error("TTS failed: %s", e)
        raise HTTPException(status_code=502, detail=str(e))

    return Response(content=audio_bytes, media_type="audio/mpeg")


@router.get("/health")
async def health(request: Request):
    """
    Returns server status, active backend configuration, and infrastructure readiness.

    Useful for:
    - Confirming which model backends are active (groq vs local)
    - Checking if Ollama is reachable before sending a live turn
    - Monitoring GPU VRAM headroom on the local machine
    """
    groq_ready = (
        hasattr(request.app.state, "groq_client")
        and request.app.state.groq_client is not None
    )

    # Ping Ollama when conversation or evaluation uses the Ollama daemon.
    ollama_reachable: bool | None = None
    if settings.llm_backend == "ollama" or settings.eval_llm_backend == "ollama":
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                resp = await client.get(f"{settings.ollama_base_url}/api/tags")
                ollama_reachable = resp.status_code == 200
        except Exception:
            ollama_reachable = False

    # GPU VRAM via nvidia-smi (returns None on machines without an NVIDIA GPU).
    gpu_info: dict | None = None
    try:
        result = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=memory.used,memory.total",
                "--format=csv,noheader,nounits",
            ],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if result.returncode == 0 and result.stdout.strip():
            used_str, total_str = result.stdout.strip().split(",")
            gpu_info = {
                "vram_used_mb": int(used_str.strip()),
                "vram_total_mb": int(total_str.strip()),
            }
    except Exception:
        pass

    ctranslate2_version: str | None = None
    faster_whisper_version: str | None = None
    try:
        ctranslate2_version = importlib.metadata.version("ctranslate2")
    except importlib.metadata.PackageNotFoundError:
        pass
    try:
        faster_whisper_version = importlib.metadata.version("faster-whisper")
    except importlib.metadata.PackageNotFoundError:
        pass

    response: dict = {
        "status": "ok",
        "groq_ready": groq_ready,
        "backends": {
            "asr": settings.asr_backend,
            "llm": settings.llm_backend,
            "tts": settings.tts_backend,
        },
        "local_models": {
            "whisper_model": settings.whisper_model,
            "whisper_device": settings.whisper_device,
            "whisper_compute_type": settings.whisper_compute_type,
            "ollama_model": settings.ollama_model,
            "kokoro_voice": settings.kokoro_voice,
        },
    }

    if ctranslate2_version or faster_whisper_version:
        response["cp1_local_stack"] = {
            k: v
            for k, v in (
                ("ctranslate2_version", ctranslate2_version),
                ("faster_whisper_version", faster_whisper_version),
            )
            if v
        }

    if ollama_reachable is not None:
        response["ollama_reachable"] = ollama_reachable

    uses_openai_compat = (
        settings.llm_backend == "openai_compat"
        or settings.eval_llm_backend == "openai_compat"
    )
    if uses_openai_compat:
        response["openai_compat"] = {
            "configured": bool(
                settings.openai_compat_base_url and settings.openai_compat_api_key
            ),
            "base_url_host": (
                settings.openai_compat_base_url.split("//")[-1].split("/")[0]
                if settings.openai_compat_base_url
                else None
            ),
        }

    if gpu_info:
        response["gpu"] = gpu_info

    return response
