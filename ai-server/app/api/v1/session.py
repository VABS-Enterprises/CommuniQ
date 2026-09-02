import base64
import json
import logging
from typing import Optional

from fastapi import APIRouter, Depends, Form, HTTPException, UploadFile
from groq import AsyncGroq

from app.config import settings
from app.core.prompts import build_evaluator_prompt, build_roleplay_evaluator_prompt
from app.dependencies import get_groq_client, verify_internal_api_key
from app.schemas.session import (
    EvaluateRequest,
    EvaluateResponse,
    OpeningRequest,
    OpeningResponse,
    TurnResponse,
)
from app.services import asr_facade, llm_facade, tts_facade
from app.services.evaluator import parse_evaluation
from app.services.stt import MAX_AUDIO_BYTES, MIN_AUDIO_BYTES

logger = logging.getLogger("communiq")

LLM_MODEL = settings.llm_model

router = APIRouter(dependencies=[Depends(verify_internal_api_key)])

# Opening nudge sent as the first user message so the LLM starts the scene.
_OPENING_USER_MESSAGE = "Start the interview now."

# Appended to the system prompt for the opening turn only.
# Keeps the first line short — it is TTS-synthesised and the user hears it
# before they can speak, so a long monologue wastes several seconds.
_OPENING_VOICE_SUFFIX = (
    "\n\nVoice mode — opening line only: Deliver ONE short, natural spoken "
    "sentence (max 20 words) to open the conversation. "
    "No lists, no asterisks, no markdown. Speak as if you just picked up the phone."
)


def _convert_history(raw_history: list) -> list[dict]:
    """
    Convert Node/Firestore turn format to OpenAI chat format.

    Node sends:  [{"role": "user"|"ai", "transcript": "...", "timestamp": "..."}]
    Groq needs:  [{"role": "user"|"assistant", "content": "..."}]
    """
    result = []
    for turn in raw_history:
        if not isinstance(turn, dict):
            continue
        role = "assistant" if turn.get("role") == "ai" else turn.get("role", "user")
        content = turn.get("transcript", "").strip()
        if content:
            result.append({"role": role, "content": content})
    return result


# ─── POST /session/opening ──────────────────────────────────────────────────

@router.post("/session/opening", response_model=OpeningResponse)
async def session_opening(
    req: OpeningRequest,
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Generate the first AI line + TTS before any user audio (Colab parity).

    LLM sees: system = scenario prompt, user = "Start the interview now."
    """
    logger.info("Opening start — session=%s", req.sessionId)

    try:
        response = await llm_facade.chat_completion(
            groq,
            model=LLM_MODEL,
            messages=[
                {"role": "system", "content": req.systemPrompt + _OPENING_VOICE_SUFFIX},
                {"role": "user", "content": _OPENING_USER_MESSAGE},
            ],
            max_tokens=80,
            temperature=0.75,
            timeout=20,
        )
    except Exception as e:
        logger.error("Opening LLM failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="AI opening failed. Please try again."
        ) from e

    ai_reply = llm_facade.content_of(response)
    if not ai_reply:
        raise HTTPException(
            status_code=502, detail="AI returned an empty opening. Please try again."
        )

    logger.info("Opening LLM done — session=%s chars=%d", req.sessionId, len(ai_reply))

    try:
        audio_out = await tts_facade.synthesize_full(ai_reply)
    except RuntimeError as e:
        logger.error("Opening TTS failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="Voice synthesis failed. Please try again."
        ) from e

    ai_audio_base64 = base64.b64encode(audio_out).decode("utf-8")
    logger.info("Opening TTS done — session=%s", req.sessionId)

    return OpeningResponse(aiReply=ai_reply, aiAudioBase64=ai_audio_base64)


# ─── POST /session/turn ───────────────────────────────────────────────────────

@router.post("/session/turn", response_model=TurnResponse)
async def session_turn(
    audioFile: UploadFile,
    sessionId: str = Form(...),
    conversationHistory: str = Form(default="[]"),
    systemPrompt: str = Form(...),
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Process one conversation turn for an active session.

    Called by the Node backend (POST /sessions/turn) after VAD detects
    end of user speech. Node proxies the audio and context here, then
    writes the returned transcripts to Firestore.

    Accepts (multipart/form-data):
        audioFile           — raw audio bytes (m4a / wav / webm)
        sessionId           — used for structured logging
        conversationHistory — JSON array of {role, transcript} turns from Firestore
        systemPrompt        — pre-built LLM persona prompt from the scenario document

    Returns JSON:
        { userTranscript, aiReply, aiAudioBase64 }
    """
    audio_bytes = await audioFile.read()
    filename = audioFile.filename or "audio.wav"

    # ── Audio validation ──────────────────────────────────────────────────────
    if not audio_bytes:
        raise HTTPException(status_code=422, detail="Audio file is empty.")
    if len(audio_bytes) < MIN_AUDIO_BYTES:
        raise HTTPException(
            status_code=422,
            detail="Audio file is too small — recording may be too short or corrupted.",
        )
    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Audio file too large. Maximum is {MAX_AUDIO_BYTES // 1024 // 1024} MB.",
        )

    # ── Parse conversation history ────────────────────────────────────────────
    try:
        raw_history = json.loads(conversationHistory)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=422, detail="'conversationHistory' must be valid JSON."
        )
    if not isinstance(raw_history, list):
        raise HTTPException(
            status_code=422, detail="'conversationHistory' must be a JSON array."
        )

    # ── Step 1: STT ───────────────────────────────────────────────────────────
    logger.info(
        "STT start — session=%s file=%s size=%d bytes",
        sessionId, filename, len(audio_bytes),
    )
    try:
        user_transcript = await asr_facade.transcribe(audio_bytes, filename, groq)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except RuntimeError as e:
        logger.error("STT failed — session=%s: %s", sessionId, e)
        raise HTTPException(
            status_code=502, detail="Speech recognition failed. Please try again."
        )
    logger.info("STT done — session=%s transcript=%d chars", sessionId, len(user_transcript))

    # ── Step 2: LLM ──────────────────────────────────────────────────────────
    messages = [{"role": "system", "content": systemPrompt}]
    messages.extend(_convert_history(raw_history))
    messages.append({"role": "user", "content": user_transcript})

    logger.info("LLM start — session=%s messages=%d", sessionId, len(messages))
    try:
        response = await llm_facade.chat_completion(
            groq,
            model=LLM_MODEL,
            messages=messages,
            max_tokens=256,
            temperature=0.75,
            timeout=25,
        )
    except Exception as e:
        logger.error("LLM failed — session=%s: %s", sessionId, e)
        raise HTTPException(
            status_code=502, detail="AI response failed. Please try again."
        )

    ai_reply = llm_facade.content_of(response)
    if not ai_reply:
        raise HTTPException(
            status_code=502, detail="AI returned an empty response. Please try again."
        )
    logger.info("LLM done — session=%s reply=%d chars", sessionId, len(ai_reply))

    # ── Step 3: TTS ───────────────────────────────────────────────────────────
    logger.info("TTS start — session=%s text=%d chars", sessionId, len(ai_reply))
    try:
        audio_out = await tts_facade.synthesize_full(ai_reply)
    except RuntimeError as e:
        logger.error("TTS failed — session=%s: %s", sessionId, e)
        raise HTTPException(
            status_code=502, detail="Voice synthesis failed. Please try again."
        )

    ai_audio_base64 = base64.b64encode(audio_out).decode("utf-8")
    logger.info(
        "TTS done — session=%s audio=%d bytes", sessionId, len(audio_out)
    )

    return TurnResponse(
        userTranscript=user_transcript,
        aiReply=ai_reply,
        aiAudioBase64=ai_audio_base64,
    )


# ─── POST /session/evaluate ───────────────────────────────────────────────────
# DEPRECATED — kept as a backward-compatible alias for POST /evaluate/roleplay.
# Node's fastApiService.js now calls /evaluate/roleplay directly.
# This endpoint will be removed in a future release.

@router.post("/session/evaluate", response_model=EvaluateResponse)
async def session_evaluate(
    req: EvaluateRequest,
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Deprecated alias for POST /evaluate/roleplay.

    Kept for backward compatibility — do not use for new integrations.
    The canonical evaluation endpoint is POST /evaluate/roleplay.
    """
    system_prompt = build_roleplay_evaluator_prompt(req.scenarioType)

    logger.info(
        "[DEPRECATED /session/evaluate] Evaluation start — session=%s scenario=%s transcript=%d chars",
        req.sessionId, req.scenarioType, len(req.fullTranscript),
    )

    try:
        response = await llm_facade.eval_chat_completion(
            groq,
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": f"Evaluate this session transcript:\n\n{req.fullTranscript}",
                },
            ],
            max_tokens=1024,
            temperature=0.2,
            timeout=50,
        )
    except Exception as e:
        logger.error("Evaluation LLM request failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="Evaluation service unavailable. Please try again."
        ) from e

    raw = llm_facade.content_of(response)

    try:
        result = parse_evaluation(raw)
    except ValueError as e:
        # Raw excerpt kept short — it's raw LLM output and may quote the
        # user's own speech, so only log enough to debug the parse failure.
        logger.error(
            "Evaluation parse failed — session=%s: %s\nRaw output: %s",
            req.sessionId, e, raw[:100],
        )
        raise HTTPException(
            status_code=500, detail=f"Evaluation parsing failed: {e}"
        ) from e

    logger.info("Evaluation complete — session=%s", req.sessionId)

    return EvaluateResponse(
        scores=result["scores"],
        fillerWordCount=result["filler_count"],
        fillerWords=result["filler_words"],
        strengths=result["strengths"],
        improvements=result["improvements"],
        recommendedNextType=result["recommended_next"],
    )
