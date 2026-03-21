import base64
import json
import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Form, HTTPException, Response, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from groq import AsyncGroq
from pydantic import BaseModel, field_validator

from .evaluator import parse_evaluation
from .prompts import VALID_LEVELS, build_evaluator_prompt, build_system_prompt
from .stt import MAX_AUDIO_BYTES, transcribe
from .tts import DEFAULT_VOICE, should_flush_buffer, split_sentences, synthesize_full, synthesize_sentence, validate_voice

load_dotenv()

logger = logging.getLogger("communiq")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

LLM_MODEL = "llama-3.1-8b-instant"
MAX_TRANSCRIPT_CHARS = 20_000   # ~5000 words — hard cap on /evaluate input

_groq_client: AsyncGroq | None = None


def _get_groq() -> AsyncGroq:
    global _groq_client
    if _groq_client is None:
        raise RuntimeError("Groq client not initialised. Server may still be starting up.")
    return _groq_client


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise shared resources at startup, clean up at shutdown."""
    global _groq_client
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError(
            "GROQ_API_KEY is not set. Add it to ai-server/.env and restart the server."
        )
    _groq_client = AsyncGroq(api_key=api_key)
    logger.info("Groq client initialised.")
    yield
    _groq_client = None
    logger.info("Groq client released.")


app = FastAPI(title="CommuniQ AI Server", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── /conversation ────────────────────────────────────────────────────────────

@app.post("/conversation")
async def conversation(
    audio: UploadFile,
    messages: str = Form(...),
    scenario_prompt: str = Form(...),
    agent_description: str = Form(...),
    agent_voice: str = Form(...),
    level: str = Form(...),
    voice_id: str = Form(default=DEFAULT_VOICE),
):
    """
    Primary conversation turn endpoint.
    Accepts an audio recording + session context.
    Returns a Server-Sent Events stream:

      { type: "transcript",  text: "..."       }  — user speech transcribed
      { type: "text_chunk",  text: "token"     }  — one LLM token (for live text display)
      { type: "audio_chunk", data: "base64mp3" }  — one synthesised sentence
      { type: "done"                           }  — turn complete, mic can reopen
      { type: "error",       message: "..."    }  — recoverable error
    """
    # Validate level early so we fail fast before touching Groq
    level = level.lower().strip()
    if level not in VALID_LEVELS:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid level '{level}'. Must be one of: {sorted(VALID_LEVELS)}."
        )

    audio_bytes = await audio.read()

    if not audio_bytes:
        raise HTTPException(status_code=422, detail="Audio file is empty.")

    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Audio file too large. Maximum size is {MAX_AUDIO_BYTES // 1024 // 1024} MB."
        )

    try:
        parsed_messages = json.loads(messages)
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="'messages' must be a valid JSON array.")

    if not isinstance(parsed_messages, list):
        raise HTTPException(status_code=422, detail="'messages' must be a JSON array.")

    resolved_voice = validate_voice(voice_id)
    filename = audio.filename or "audio.m4a"

    return StreamingResponse(
        _conversation_stream(
            audio_bytes=audio_bytes,
            filename=filename,
            messages=parsed_messages,
            scenario_prompt=scenario_prompt,
            agent_description=agent_description,
            agent_voice=agent_voice,
            level=level,
            voice_id=resolved_voice,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


async def _conversation_stream(
    audio_bytes: bytes,
    filename: str,
    messages: list[dict],
    scenario_prompt: str,
    agent_description: str,
    agent_voice: str,
    level: str,
    voice_id: str,
):
    def sse(event: dict) -> str:
        return f"data: {json.dumps(event, ensure_ascii=False)}\n\n"

    try:
        # Step 1 — Transcribe audio
        logger.info("STT start — %s, %d bytes", filename, len(audio_bytes))
        transcript = await transcribe(audio_bytes, filename)
        logger.info("STT done — %d chars", len(transcript))
        yield sse({"type": "transcript", "text": transcript})

        # Step 2 — Assemble conversation history
        system_prompt = build_system_prompt(scenario_prompt, agent_description, agent_voice, level)
        history = [{"role": "system", "content": system_prompt}]
        history.extend(messages)
        history.append({"role": "user", "content": transcript})

        # Step 3 — Stream LLM tokens, synthesise sentences as they complete
        logger.info("LLM stream start — %d history messages", len(history))
        client = _get_groq()
        stream = await client.chat.completions.create(
            model=LLM_MODEL,
            messages=history,
            stream=True,
            max_tokens=256,
            temperature=0.75,
        )

        token_buffer = ""

        async for chunk in stream:
            delta = chunk.choices[0].delta.content or ""
            if not delta:
                continue

            token_buffer += delta
            yield sse({"type": "text_chunk", "text": delta})

            sentences = split_sentences(token_buffer)
            if len(sentences) > 1:
                # Natural boundary — synthesise all completed chunks
                for sentence in sentences[:-1]:
                    audio_chunk = await synthesize_sentence(sentence, voice_id)
                    if audio_chunk:
                        yield sse({
                            "type": "audio_chunk",
                            "data": base64.b64encode(audio_chunk).decode()
                        })
                token_buffer = sentences[-1]

            elif should_flush_buffer(token_buffer):
                # Buffer too long without punctuation — synthesise now to prevent silent gap
                audio_chunk = await synthesize_sentence(token_buffer.strip(), voice_id)
                if audio_chunk:
                    yield sse({
                        "type": "audio_chunk",
                        "data": base64.b64encode(audio_chunk).decode()
                    })
                token_buffer = ""

        # Synthesise any remaining buffer after the stream ends
        if token_buffer.strip():
            audio_chunk = await synthesize_sentence(token_buffer.strip(), voice_id)
            if audio_chunk:
                yield sse({
                    "type": "audio_chunk",
                    "data": base64.b64encode(audio_chunk).decode()
                })

        logger.info("Conversation turn complete.")
        yield sse({"type": "done"})

    except ValueError as e:
        # Input validation errors (empty audio, empty transcript, etc.)
        logger.warning("Conversation input error: %s", e)
        yield sse({"type": "error", "message": str(e)})

    except Exception as e:
        logger.error("Conversation stream error: %s", e, exc_info=True)
        yield sse({"type": "error", "message": "An error occurred processing this turn. Please try again."})


# ─── /evaluate ────────────────────────────────────────────────────────────────

class EvaluateRequest(BaseModel):
    transcript: str
    scenario_prompt: str
    agent_description: str
    level: str

    @field_validator("level")
    @classmethod
    def validate_level(cls, v: str) -> str:
        v = v.lower().strip()
        if v not in VALID_LEVELS:
            raise ValueError(f"Invalid level '{v}'. Must be one of: {sorted(VALID_LEVELS)}.")
        return v

    @field_validator("transcript")
    @classmethod
    def validate_transcript(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Transcript must not be empty.")
        if len(v) > MAX_TRANSCRIPT_CHARS:
            raise ValueError(
                f"Transcript too long ({len(v)} chars). "
                f"Maximum is {MAX_TRANSCRIPT_CHARS} characters."
            )
        return v.strip()


@app.post("/evaluate")
async def evaluate(req: EvaluateRequest):
    """
    Evaluate a completed conversation session.
    Returns a validated JSON performance report with scores, filler analysis,
    strengths, improvements, and a recommended next session.
    """
    system_prompt = build_evaluator_prompt(req.scenario_prompt, req.agent_description, req.level)
    logger.info("Evaluation start — level=%s, transcript=%d chars", req.level, len(req.transcript))

    client = _get_groq()
    try:
        response = await client.chat.completions.create(
            model=LLM_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Transcript to evaluate:\n\n{req.transcript}"},
            ],
            stream=False,
            max_tokens=1024,
            temperature=0.2,
        )
    except Exception as e:
        logger.error("Groq evaluation request failed: %s", e)
        raise HTTPException(status_code=502, detail="Evaluation service unavailable. Please try again.")

    raw = response.choices[0].message.content or ""

    try:
        result = parse_evaluation(raw)
    except ValueError as e:
        logger.error("Evaluation parse failed: %s\nRaw: %s", e, raw[:500])
        raise HTTPException(status_code=500, detail=f"Evaluation parsing failed: {e}")

    logger.info("Evaluation complete.")
    return result


# ─── /tts ─────────────────────────────────────────────────────────────────────

class TTSRequest(BaseModel):
    text: str
    voice: str | None = None

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Text must not be empty.")
        if len(v) > 2000:
            raise ValueError("Text too long. Maximum is 2000 characters for TTS.")
        return v.strip()


@app.post("/tts")
async def tts(req: TTSRequest):
    """
    Synthesise text to MP3 audio.
    Used for the AI's session-opening message and any standalone TTS needs.
    """
    resolved_voice = validate_voice(req.voice)
    try:
        audio_bytes = await synthesize_full(req.text, resolved_voice)
    except RuntimeError as e:
        logger.error("TTS failed: %s", e)
        raise HTTPException(status_code=502, detail=str(e))

    return Response(content=audio_bytes, media_type="audio/mpeg")


# ─── /health ──────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """Returns server status and whether the Groq client is ready."""
    return {
        "status": "ok",
        "groq_ready": _groq_client is not None,
        "model": LLM_MODEL,
    }
