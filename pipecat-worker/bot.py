"""
Pipecat bot — one instance per active CommuniQ roleplay session.

Pipeline (LiveKit live-voice mode):

  LiveKitTransport.input()          (WebRTC mic frames from Flutter)
    → VADProcessor                  (SileroVAD turn detection)
    → GroqSTTService                (Whisper-large-v3-turbo via Groq cloud)
    → UserTranscriptCapture         (stores user transcript + sends to Flutter)
    → LLMUserAggregator             (adds transcription to chat context)
    → GroqLLMService                (llama-3.1-8b-instant)
    → AiTranscriptPoster            (aggregates AI text, POSTs turn to Node,
                                     sends transcript + ai_done to Flutter)
    → EdgeTTSService                (Microsoft Edge TTS — free, no rate limits)
    → LiveKitTransport.output()     (streams AI audio back to Flutter)
    → LLMAssistantAggregator        (adds AI reply to chat context)

Turn sync:
  After each AI response AiTranscriptPoster POSTs
  { sessionId, userTranscript, aiTranscript }
  to POST /sessions/internal/live-voice-turn on the Node backend
  so that /sessions/end evaluation sees the full live-voice conversation.

UI sync (LiveKit data channel):
  UserTranscriptCapture → {"type": "user_transcript", "text": "..."}
  AiTranscriptPoster    → {"type": "ai_transcript",   "text": "..."}
  AiTranscriptPoster    → {"type": "ai_done"}  (on BotStoppedSpeakingFrame upstream)
"""

import asyncio
import json
import logging
import os
from typing import AsyncGenerator, Optional

import edge_tts
import httpx
from dotenv import load_dotenv

from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import (
    BotStoppedSpeakingFrame,
    EndFrame,
    ErrorFrame,
    Frame,
    LLMFullResponseEndFrame,
    LLMTextFrame,
    TTSAudioRawFrame,
    TranscriptionFrame,
)
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import LLMContextAggregatorPair
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor
from pipecat.services.groq.llm import GroqLLMService
from pipecat.services.groq.stt import GroqSTTService
from pipecat.services.settings import TTSSettings
from pipecat.services.tts_service import TTSService
from pipecat.transports.livekit.transport import LiveKitParams, LiveKitTransport

load_dotenv()

logger = logging.getLogger("communiq.bot")

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
NODE_BACKEND_URL = os.getenv("NODE_BACKEND_URL", "http://localhost:3000").rstrip("/")
PIPECAT_WEBHOOK_SECRET = os.getenv("PIPECAT_WEBHOOK_SECRET", "")

# ─── Edge TTS service ─────────────────────────────────────────────────────────

_EDGE_TTS_VOICE = os.getenv("EDGE_TTS_VOICE", "en-IN-PrabhatNeural")
_EDGE_TTS_SAMPLE_RATE = 24000
_EDGE_TTS_CHUNK_MS = 20  # PCM chunk size in ms for smooth playback


class EdgeTTSService(TTSService):
    """
    Microsoft Edge TTS via the `edge-tts` + `ffmpeg` pipeline.

    Completely free with no rate limits.
    Streams MP3 chunks from edge-tts into an ffmpeg subprocess which
    decodes them to 24 kHz 16-bit PCM in real time, yielding audio
    frames as soon as the first chunk arrives (~300 ms TTFB).
    """

    class Settings(TTSSettings):
        model: str = "edge-tts"
        voice: str = _EDGE_TTS_VOICE
        language: None = None  # edge-tts infers language from the voice name

    def __init__(self, voice: str = _EDGE_TTS_VOICE, **kwargs) -> None:
        settings = EdgeTTSService.Settings(model="edge-tts", voice=voice, language=None)
        super().__init__(sample_rate=_EDGE_TTS_SAMPLE_RATE, settings=settings, **kwargs)
        self._voice = voice

    async def run_tts(self, text: str, context_id: str) -> AsyncGenerator[Frame, None]:
        logger.debug("EdgeTTSService: Generating TTS [%s]", text)
        proc = None
        try:
            # Start an ffmpeg subprocess that reads MP3 from stdin and writes
            # raw 16-bit PCM at 24 kHz mono to stdout.
            proc = await asyncio.create_subprocess_exec(
                "ffmpeg",
                "-loglevel", "error",
                "-f", "mp3", "-i", "pipe:0",
                "-f", "s16le", "-ar", str(_EDGE_TTS_SAMPLE_RATE), "-ac", "1",
                "pipe:1",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
            )

            async def _feed_mp3() -> None:
                """Stream edge-tts MP3 chunks into ffmpeg stdin."""
                try:
                    communicate = edge_tts.Communicate(text, self._voice)
                    async for chunk in communicate.stream():
                        if chunk["type"] == "audio":
                            proc.stdin.write(chunk["data"])
                    proc.stdin.close()
                except Exception as exc:
                    logger.error("EdgeTTS feed error: %s", exc)
                    try:
                        proc.stdin.close()
                    except Exception:
                        pass

            feed_task = asyncio.create_task(_feed_mp3(), name="edge-tts-feed")

            # Read PCM from ffmpeg stdout and yield as audio frames.
            pcm_chunk_bytes = _EDGE_TTS_SAMPLE_RATE * 2 * _EDGE_TTS_CHUNK_MS // 1000
            await self.stop_ttfb_metrics()
            while True:
                pcm = await proc.stdout.read(pcm_chunk_bytes)
                if not pcm:
                    break
                yield TTSAudioRawFrame(
                    audio=pcm,
                    sample_rate=_EDGE_TTS_SAMPLE_RATE,
                    num_channels=1,
                    context_id=context_id,
                )

            await feed_task  # ensure feeder finished cleanly
            await proc.wait()

        except Exception as exc:
            logger.error("EdgeTTSService error: %s", exc)
            yield ErrorFrame(error=f"EdgeTTS error: {exc}")
        finally:
            if proc and proc.returncode is None:
                proc.kill()


# ─── Shared turn state ────────────────────────────────────────────────────────


class _TurnState:
    """Mutable state shared between the two transcript-capture processors."""

    __slots__ = ("last_user",)

    def __init__(self) -> None:
        self.last_user: str = ""


# ─── Frame processors ─────────────────────────────────────────────────────────


class UserTranscriptCapture(FrameProcessor):
    """
    Placed between GroqSTTService and LLMUserAggregator.

    Filters Whisper hallucinations (pure punctuation, standalone filler words),
    stores the clean transcript in shared TurnState for AiTranscriptPoster, and
    broadcasts it to Flutter via a LiveKit data message so the UI can show live
    captions without a separate STT pipeline on the client.
    """

    # Words that are noise on their own — Whisper hallucination or breath sounds.
    _SOLO_NOISE: frozenset[str] = frozenset({
        'um', 'uh', 'hmm', 'hm', 'ah', 'er', 'oh', 'so', 'yeah',
        'okay', 'ok', 'right', 'yes', 'no', 'well', 'like',
    })

    def __init__(self, state: _TurnState, transport: "LiveKitTransport", **kwargs) -> None:
        super().__init__(**kwargs)
        self._state = state
        self._transport = transport

    def _is_noise(self, text: str) -> bool:
        """Return True if text is a Whisper hallucination or standalone filler."""
        if not text or all(c in '.,!?;:…- ' for c in text) or len(text) <= 1:
            return True
        words = [w.lower().strip('.,!?;:…') for w in text.split() if w.strip('.,!?;:…')]
        if len(words) == 1 and words[0] in self._SOLO_NOISE:
            return True
        if len(words) == 2 and all(w in self._SOLO_NOISE for w in words):
            return True
        return False

    async def process_frame(self, frame: Frame, direction: FrameDirection) -> None:
        await super().process_frame(frame, direction)
        if isinstance(frame, TranscriptionFrame):
            text = frame.text.strip()
            if self._is_noise(text):
                logger.debug("User → STT (noise, filtered): %r", text)
                return  # drop — do NOT pass to LLM aggregator
            self._state.last_user = text
            logger.info("User → STT: %s", text)
            # Notify Flutter so the UI can show the live user caption.
            asyncio.create_task(
                self._transport.send_message(
                    json.dumps({"type": "user_transcript", "text": text})
                ),
                name="ui-user-transcript",
            )
            await self.push_frame(frame, direction)
            return
        await self.push_frame(frame, direction)


class AiTranscriptPoster(FrameProcessor):
    """
    Placed between GroqLLMService and EdgeTTSService.

    1. Accumulates LLMTextFrame chunks from the LLM and, upon
       LLMFullResponseEndFrame, POSTs the complete (user, AI) turn pair to
       POST /sessions/internal/live-voice-turn on the Node backend.
    2. Sends the AI text to Flutter via LiveKit data message so the UI can
       display it while the audio plays ("ai_transcript").
    3. Catches BotStoppedSpeakingFrame flowing upstream from the transport
       output and sends an "ai_done" signal to Flutter so the UI can switch
       back to the user-turn state once the AI finishes speaking.

    All frames are passed through unchanged.
    """

    def __init__(self, session_id: str, state: _TurnState, transport: "LiveKitTransport", **kwargs) -> None:
        super().__init__(**kwargs)
        self._session_id = session_id
        self._state = state
        self._transport = transport
        self._ai_buffer: list[str] = []

    async def process_frame(self, frame: Frame, direction: FrameDirection) -> None:
        await super().process_frame(frame, direction)

        if isinstance(frame, LLMTextFrame) and direction == FrameDirection.DOWNSTREAM:
            self._ai_buffer.append(frame.text)

        elif isinstance(frame, LLMFullResponseEndFrame):
            ai_text = "".join(self._ai_buffer).strip()
            self._ai_buffer.clear()
            user_text = self._state.last_user
            self._state.last_user = ""

            if user_text or ai_text:
                # Save turn to Firestore via Node backend (for evaluation).
                asyncio.create_task(
                    self._post_turn(user_text, ai_text),
                    name=f"post-turn-{self._session_id}",
                )
            if ai_text:
                # Tell Flutter to show the AI's response in the conversation card.
                asyncio.create_task(
                    self._transport.send_message(
                        json.dumps({"type": "ai_transcript", "text": ai_text})
                    ),
                    name="ui-ai-transcript",
                )

        elif isinstance(frame, BotStoppedSpeakingFrame) and direction == FrameDirection.UPSTREAM:
            # Bot finished playing audio — signal Flutter to return to user-turn state.
            asyncio.create_task(
                self._transport.send_message(json.dumps({"type": "ai_done"})),
                name="ui-ai-done",
            )

        await self.push_frame(frame, direction)

    async def _post_turn(self, user_transcript: str, ai_transcript: str) -> None:
        url = f"{NODE_BACKEND_URL}/sessions/internal/live-voice-turn"
        payload = {
            "sessionId": self._session_id,
            "userTranscript": user_transcript,
            "aiTranscript": ai_transcript,
        }
        headers = {"X-Communiq-Worker-Secret": PIPECAT_WEBHOOK_SECRET}

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code in (200, 201):
                logger.info(
                    "[%s] Turn synced — user=%d chars, ai=%d chars",
                    self._session_id,
                    len(user_transcript),
                    len(ai_transcript),
                )
            else:
                logger.warning(
                    "[%s] live-voice-turn POST returned %d: %s",
                    self._session_id,
                    resp.status_code,
                    resp.text[:300],
                )
        except Exception as exc:
            logger.error("[%s] Failed to sync turn to Node: %s", self._session_id, exc)


# ─── Bot entrypoint ───────────────────────────────────────────────────────────


async def run_bot(
    session_id: str,
    livekit_url: str,
    agent_token: str,
    system_prompt: str,
    opening_text: str = "",
    groq_api_key: Optional[str] = None,
) -> None:
    """
    Connect to the LiveKit room and run the Pipecat conversation pipeline
    until the Flutter participant leaves or the session ends.

    Parameters
    ----------
    session_id   : CommuniQ session UUID (also the LiveKit room name).
    livekit_url  : LiveKit server WebSocket URL (wss://...).
    agent_token  : JWT minted by the Node server for the Pipecat agent identity.
    system_prompt: Full scenario prompt with persona/tone/level modifiers applied.
    opening_text : The opening AI line already played to the user by the ai-server.
                   Seeded into the LLM context as the first assistant message so
                   the bot doesn't re-introduce itself on the first user turn.
    groq_api_key : Override the GROQ_API_KEY env var (useful in tests).
    """
    api_key = groq_api_key or GROQ_API_KEY
    if not api_key:
        raise RuntimeError("GROQ_API_KEY is not set — cannot start Pipecat bot.")

    logger.info("[%s] Bot starting — room=%s", session_id, livekit_url)

    # ── Transport ─────────────────────────────────────────────────────────────
    transport = LiveKitTransport(
        url=livekit_url,
        token=agent_token,
        room_name=session_id,
        params=LiveKitParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
        ),
    )

    vad = VADProcessor(
        vad_analyzer=SileroVADAnalyzer(
            params=VADParams(
                confidence=0.5,   # default 0.7 — lower to catch quieter speech
                min_volume=0.05,  # default 0.6 — emulator/device mics are much quieter
                start_secs=0.2,
                stop_secs=0.2,    # keep at default — Smart Turn model is calibrated for 0.2s
            )
        )
    )

    # ── STT ───────────────────────────────────────────────────────────────────
    stt = GroqSTTService(
        api_key=api_key,
        settings=GroqSTTService.Settings(
            model="whisper-large-v3-turbo",
            prompt=(
                "This is a spoken English conversation between an Indian professional "
                "or student and an AI roleplay partner. Transcribe accurately "
                "including filler words like um, uh, like."
            ),
        ),
    )

    # ── LLM ───────────────────────────────────────────────────────────────────
    llm = GroqLLMService(
        api_key=api_key,
        settings=GroqLLMService.Settings(
            model="llama-3.1-8b-instant",
            max_completion_tokens=256,
            temperature=0.75,
        ),
    )

    # ── TTS ───────────────────────────────────────────────────────────────────
    # Using Microsoft Edge TTS (free, no rate limits).
    # Groq Orpheus has only 3,600 tokens/day on the free tier — too low for
    # even a single session, so it is not used here.
    tts = EdgeTTSService()

    # ── Context (chat history) ────────────────────────────────────────────────
    # Append a voice-mode instruction so the LLM keeps replies short and
    # plain-text only — no markdown, no bullet points.  Long responses burn
    # TTS tokens and feel unnatural in conversation.
    voice_suffix = (
        "\n\nIMPORTANT — Voice mode: Respond in spoken English only. "
        "Keep each reply to 1–3 sentences. "
        "Never use bullet points, numbered lists, asterisks, or markdown. "
        "Speak naturally as if in a real conversation. "
        "If the user's message is very short or seems like the beginning of a "
        "longer thought, give a brief acknowledgment and invite them to continue."
    )
    messages: list[dict] = [{"role": "system", "content": system_prompt + voice_suffix}]
    # Seed the opening line so the bot knows what it already said.
    # Without this the LLM starts with an empty context and re-introduces itself.
    if opening_text and opening_text.strip():
        messages.append({"role": "assistant", "content": opening_text.strip()})
        logger.info("[%s] Seeded opening into LLM context (%d chars)", session_id, len(opening_text))
    context = LLMContext(messages=messages)
    context_aggregator = LLMContextAggregatorPair(context)

    # ── Turn-sync + UI-sync processors ───────────────────────────────────────
    turn_state = _TurnState()
    user_capture = UserTranscriptCapture(state=turn_state, transport=transport)
    ai_poster = AiTranscriptPoster(session_id=session_id, state=turn_state, transport=transport)

    # ── Pipeline ──────────────────────────────────────────────────────────────
    #
    #  transport.input   — WebRTC audio frames from Flutter mic
    #  vad               — SileroVAD: emits VADUserStarted/StoppedSpeakingFrame
    #  stt               — Groq Whisper: segments on VAD events → TranscriptionFrame
    #  user_capture      — records TranscriptionFrame.text in turn_state
    #  context_agg.user  — adds transcription into LLM message history
    #  llm               — Groq Llama: streams LLMTextFrame + LLMFullResponseEndFrame
    #  ai_poster         — collects LLMTextFrames, POSTs turn pair to Node
    #  tts               — Groq PlayAI TTS: text → audio frames
    #  transport.output  — sends audio frames back to Flutter via WebRTC
    #  context_agg.asst  — adds the AI reply to LLM message history
    #
    pipeline = Pipeline(
        [
            transport.input(),
            vad,
            stt,
            user_capture,
            context_aggregator.user(),
            llm,
            ai_poster,
            tts,
            transport.output(),
            context_aggregator.assistant(),
        ]
    )

    task = PipelineTask(
        pipeline,
        params=PipelineParams(allow_interruptions=True),
    )

    # ── Event handlers ────────────────────────────────────────────────────────

    @transport.event_handler("on_first_participant_joined")
    async def on_first_participant_joined(transport, participant_id):
        logger.info("[%s] Flutter joined — participant=%s", session_id, participant_id)
        # Audio is captured automatically via auto_subscribe=True in the LiveKit room.
        # No manual capture_participant_audio call is needed in Pipecat 1.0.0.

    @transport.event_handler("on_participant_left")
    async def on_participant_left(transport, participant_id, reason):
        logger.info(
            "[%s] Participant left (%s) — sending EndFrame to pipeline.",
            session_id,
            reason,
        )
        await task.queue_frame(EndFrame())

    # ── Run ───────────────────────────────────────────────────────────────────
    runner = PipelineRunner()
    try:
        await runner.run(task)
    finally:
        logger.info("[%s] Bot pipeline finished.", session_id)
