"""
Pipecat bot — one instance per active CommuniQ roleplay session.

Pipeline (LiveKit live-voice mode):

  LiveKitTransport.input()          (WebRTC mic frames from Flutter)
    → VADProcessor                  (SileroVAD turn detection)
    → GroqSTTService                (Whisper-large-v3-turbo via Groq cloud)
    → UserTranscriptCapture         (stores user transcript + sends to Flutter)
    → LLMUserAggregator             (adds transcription to chat context)
    → GroqLLMService                (openai/gpt-oss-20b)
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
import re
from typing import AsyncGenerator, Optional

import edge_tts
import httpx
from dotenv import load_dotenv

from pipecat.audio.turn.smart_turn.base_smart_turn import SmartTurnParams
from pipecat.audio.turn.smart_turn.local_smart_turn_v3 import LocalSmartTurnAnalyzerV3
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import (
    AudioRawFrame,
    BotStartedSpeakingFrame,
    BotStoppedSpeakingFrame,
    EndFrame,
    ErrorFrame,
    Frame,
    LLMFullResponseEndFrame,
    LLMTextFrame,
    TTSAudioRawFrame,
    TranscriptionFrame,
    UserStartedSpeakingFrame,
    UserStoppedSpeakingFrame,
)
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    LLMContextAggregatorPair,
    LLMUserAggregatorParams,
)
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor
from pipecat.turns.user_stop.turn_analyzer_user_turn_stop_strategy import TurnAnalyzerUserTurnStopStrategy
from pipecat.turns.user_turn_strategies import UserTurnStrategies
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

# Hard wall-clock cap on a single live-voice session. Without this, a client
# that never triggers on_participant_left (e.g. it stalls without cleanly
# leaving the LiveKit room) would keep the pipeline — and Groq STT+LLM
# billing — running indefinitely. There is no existing time-based session
# limit elsewhere in the codebase (server/ only caps turn COUNT via
# MAX_TURNS_PER_SESSION=50, not wall-clock duration), so this introduces one.
# 30 minutes is a generous default for a practice roleplay session.
SESSION_MAX_DURATION_SECONDS = int(os.getenv("PIPECAT_MAX_SESSION_SECONDS", str(30 * 60)))

# ─── TTS text normaliser ──────────────────────────────────────────────────────
#
# Edge TTS reads raw text, so numbers/units/abbreviations that look obvious to
# a human are often mispronounced.  We pre-process LLM output before sending
# it to the TTS service.
#
# Rules applied (in order):
#   1. mAh / Ah / kWh / W / V / GHz / MHz / kHz → spelled out
#   2. mm / cm / km / m  → "millimetres" etc.
#   3. 10 AM / 10 PM / 10 a.m. / 10 p.m. → "10 in the morning" etc.
#   4. Standalone large numbers: 1000 → "1,000" (TTS reads commas naturally)
#   5. Decimal numbers: 3.5 → "3 point 5"
#   6. Ordinals: 1st 2nd 3rd 4th → "first" "second" etc. (top 20)
#   7. Common abbreviations: CEO, CTO, HR, AI, API, UI, UX → spelled or expanded
#   8. Ellipsis … / ... → short pause (comma)
#   9. Dash — between words → comma pause
#  10. Multiple spaces / newlines → single space

_ORDINALS = {
    '1st': 'first', '2nd': 'second', '3rd': 'third', '4th': 'fourth',
    '5th': 'fifth', '6th': 'sixth', '7th': 'seventh', '8th': 'eighth',
    '9th': 'ninth', '10th': 'tenth', '11th': 'eleventh', '12th': 'twelfth',
    '13th': 'thirteenth', '14th': 'fourteenth', '15th': 'fifteenth',
    '16th': 'sixteenth', '17th': 'seventeenth', '18th': 'eighteenth',
    '19th': 'nineteenth', '20th': 'twentieth',
}

# Units that should be expanded to their spoken form.
_UNIT_MAP = [
    # Battery / electricity
    (r'(\d[\d,]*(?:\.\d+)?)\s*mAh\b', lambda m: f"{m.group(1)} milliamp hours"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*kWh\b', lambda m: f"{m.group(1)} kilowatt hours"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*Wh\b',  lambda m: f"{m.group(1)} watt hours"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*kW\b',  lambda m: f"{m.group(1)} kilowatts"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*MW\b',  lambda m: f"{m.group(1)} megawatts"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*W\b',   lambda m: f"{m.group(1)} watts"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*V\b',   lambda m: f"{m.group(1)} volts"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*Ah\b',  lambda m: f"{m.group(1)} amp hours"),
    # Frequency
    (r'(\d[\d,]*(?:\.\d+)?)\s*GHz\b', lambda m: f"{m.group(1)} gigahertz"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*MHz\b', lambda m: f"{m.group(1)} megahertz"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*kHz\b', lambda m: f"{m.group(1)} kilohertz"),
    # Storage / memory
    (r'(\d[\d,]*(?:\.\d+)?)\s*GB\b',  lambda m: f"{m.group(1)} gigabytes"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*MB\b',  lambda m: f"{m.group(1)} megabytes"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*KB\b',  lambda m: f"{m.group(1)} kilobytes"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*TB\b',  lambda m: f"{m.group(1)} terabytes"),
    # Distance
    (r'(\d[\d,]*(?:\.\d+)?)\s*km\b',  lambda m: f"{m.group(1)} kilometres"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*cm\b',  lambda m: f"{m.group(1)} centimetres"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*mm\b',  lambda m: f"{m.group(1)} millimetres"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*m\b',   lambda m: f"{m.group(1)} metres"),
    # Speed
    (r'(\d[\d,]*(?:\.\d+)?)\s*km/h\b', lambda m: f"{m.group(1)} kilometres per hour"),
    (r'(\d[\d,]*(?:\.\d+)?)\s*mph\b',  lambda m: f"{m.group(1)} miles per hour"),
    # Percentage — TTS usually reads % fine, but ensure space
    (r'(\d[\d,]*(?:\.\d+)?)%', lambda m: f"{m.group(1)} percent"),
]


def _normalise_tts(text: str) -> str:
    """
    Convert LLM-generated text into a form that Edge TTS reads naturally.
    Does NOT add SSML — works with plain text mode.
    """
    # 1. Units (most specific patterns first so mAh beats Ah, kWh beats Wh etc.)
    for pattern, repl in _UNIT_MAP:
        text = re.sub(pattern, repl, text)

    # 2. Time: "10 AM" / "10am" / "10 a.m." → "10 in the morning"
    def _time_repl(m: re.Match) -> str:
        hour = m.group(1)
        meridiem = m.group(2).lower().replace('.', '').replace(' ', '')
        period = 'in the morning' if meridiem in ('am', 'a.m') else 'in the evening'
        return f"{hour} {period}"
    text = re.sub(
        r'\b(\d{1,2})\s*([aApP]\.?[mM]\.?)\b',
        _time_repl,
        text,
    )

    # 3. Decimal numbers: 3.5 → "3 point 5"
    def _decimal_repl(m: re.Match) -> str:
        integer, decimal = m.group(1), m.group(2)
        digits = ' '.join(decimal)
        return f"{integer} point {digits}"
    # Only replace decimals not already handled by unit rules
    text = re.sub(r'\b(\d+)\.(\d+)\b', _decimal_repl, text)

    # 4. Ordinals
    for abbr, spoken in _ORDINALS.items():
        text = re.sub(rf'\b{re.escape(abbr)}\b', spoken, text, flags=re.IGNORECASE)

    # 5. Large numbers: add commas for natural TTS grouping (1000 → 1,000)
    def _add_commas(m: re.Match) -> str:
        n = m.group(0)
        # Only add commas if number is ≥4 digits and has no commas already
        if len(n) >= 4:
            return f'{int(n):,}'
        return n
    text = re.sub(r'\b\d{4,}\b', _add_commas, text)

    # 6. Ellipsis / long dashes → natural pause (comma)
    text = re.sub(r'\.{2,}|…', ',', text)
    text = re.sub(r'\s*—\s*', ', ', text)
    text = re.sub(r'\s*–\s*', ', ', text)

    # 7. Strip markdown that slipped through (asterisks, hashes)
    text = re.sub(r'\*+', '', text)
    text = re.sub(r'#+\s?', '', text)

    # 8. Collapse whitespace
    text = re.sub(r'\s+', ' ', text).strip()

    return text


# ─── Edge TTS service ─────────────────────────────────────────────────────────

_EDGE_TTS_VOICE = os.getenv("EDGE_TTS_VOICE", "en-IN-PrabhatNeural")
# +20 % faster speech — edge-tts accepts "+N%" / "-N%" strings for rate.
# Users found the default speed too slow; +20% keeps it natural for most voices.
_EDGE_TTS_RATE = os.getenv("EDGE_TTS_RATE", "+20%")
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

    def __init__(self, voice: str = _EDGE_TTS_VOICE, rate: str = _EDGE_TTS_RATE, **kwargs) -> None:
        settings = EdgeTTSService.Settings(model="edge-tts", voice=voice, language=None)
        super().__init__(sample_rate=_EDGE_TTS_SAMPLE_RATE, settings=settings, **kwargs)
        self._voice = voice
        self._rate = rate

    async def run_tts(self, text: str, context_id: str) -> AsyncGenerator[Frame, None]:
        text = _normalise_tts(text)
        logger.debug("EdgeTTSService: Generating TTS [%s]", text)
        proc = None
        try:
            # Launch ffmpeg and the edge-tts WebSocket connection concurrently.
            # ffmpeg is ready to decode the moment the first MP3 chunk arrives,
            # eliminating the sequential "start subprocess, then connect" delay.
            proc_coro = asyncio.create_subprocess_exec(
                "ffmpeg",
                "-loglevel", "error",
                # Low-latency flags: avoid buffering input until the first full
                # MP3 frame — emit PCM as soon as it is decoded.
                "-probesize", "32",
                "-analyzeduration", "0",
                "-f", "mp3", "-i", "pipe:0",
                "-f", "s16le", "-ar", str(_EDGE_TTS_SAMPLE_RATE), "-ac", "1",
                "pipe:1",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
            )
            communicate = edge_tts.Communicate(text, self._voice, rate=self._rate)

            # Open both concurrently — WebSocket handshake and subprocess
            # creation overlap instead of running one after the other.
            proc, stream_iter = await asyncio.gather(
                proc_coro,
                self._open_stream(communicate),
            )

            async def _feed_mp3() -> None:
                """Write pre-fetched edge-tts chunks into ffmpeg stdin."""
                try:
                    async for chunk in stream_iter:
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

            # Use a small initial read size (10 ms) so the first audio frame is
            # emitted as soon as any PCM is available — reduces perceived TTFB.
            first_chunk_bytes = _EDGE_TTS_SAMPLE_RATE * 2 * 10 // 1000
            normal_chunk_bytes = _EDGE_TTS_SAMPLE_RATE * 2 * _EDGE_TTS_CHUNK_MS // 1000
            first = True
            await self.stop_ttfb_metrics()
            while True:
                read_size = first_chunk_bytes if first else normal_chunk_bytes
                pcm = await proc.stdout.read(read_size)
                if not pcm:
                    break
                first = False
                yield TTSAudioRawFrame(
                    audio=pcm,
                    sample_rate=_EDGE_TTS_SAMPLE_RATE,
                    num_channels=1,
                    context_id=context_id,
                )

            await feed_task
            await proc.wait()

        except Exception as exc:
            logger.error("EdgeTTSService error: %s", exc)
            yield ErrorFrame(error=f"EdgeTTS error: {exc}")
        finally:
            if proc and proc.returncode is None:
                proc.kill()

    @staticmethod
    async def _open_stream(communicate: "edge_tts.Communicate"):
        """
        Return the async generator from edge_tts.Communicate.stream() so it
        can be awaited in gather() alongside the subprocess creation.
        The generator itself is lazy — no network I/O happens here, only
        the object construction, which is synchronous and instant.
        """
        return communicate.stream()


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


class VadDebugLogger(FrameProcessor):
    """
    Transparent pass-through that logs every VAD and speaker event so we can
    trace exactly when Silero/Smart Turn fire and how long the gaps are.

    Also samples incoming audio RMS every 2 seconds so we can confirm audio
    is actually flowing and measure mic volume levels.

    Insert it AFTER VADProcessor in the pipeline to observe its output.
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        import time
        self._speech_start_ts: float | None = None
        self._audio_frame_count: int = 0
        self._audio_rms_sum: float = 0.0
        self._last_audio_log_ts: float = time.monotonic()

    async def process_frame(self, frame: Frame, direction: FrameDirection) -> None:
        await super().process_frame(frame, direction)

        import time
        import struct
        import math
        now = time.monotonic()

        # ── Audio volume sampling (upstream audio frames from mic) ─────────────
        if isinstance(frame, AudioRawFrame) and direction == FrameDirection.DOWNSTREAM:
            # AudioRawFrame.audio is raw 16-bit PCM bytes
            data = frame.audio
            if data:
                samples = struct.unpack(f"<{len(data)//2}h", data[:len(data) - len(data)%2])
                if samples:
                    rms = math.sqrt(sum(s*s for s in samples) / len(samples)) / 32768.0
                    self._audio_rms_sum += rms
                    self._audio_frame_count += 1

            if now - self._last_audio_log_ts >= 2.0:
                avg_rms = (self._audio_rms_sum / self._audio_frame_count
                           if self._audio_frame_count > 0 else 0.0)
                logger.info(
                    "🎚  [AUDIO] frames=%d  avg_rms=%.4f  (min_volume threshold=0.04)",
                    self._audio_frame_count, avg_rms
                )
                self._audio_frame_count = 0
                self._audio_rms_sum = 0.0
                self._last_audio_log_ts = now

        # ── VAD / turn events ──────────────────────────────────────────────────
        elif isinstance(frame, UserStartedSpeakingFrame):
            self._speech_start_ts = now
            logger.info("🎤 [VAD] UserStartedSpeaking ↑")

        elif isinstance(frame, UserStoppedSpeakingFrame):
            duration = (now - self._speech_start_ts) if self._speech_start_ts else 0.0
            self._speech_start_ts = None
            logger.info("🔇 [VAD] UserStoppedSpeaking ↓  (speech lasted %.2fs)", duration)

        elif isinstance(frame, TranscriptionFrame):
            logger.info("📝 [STT] Transcription → %r", frame.text)

        elif isinstance(frame, BotStartedSpeakingFrame):
            logger.info("🔊 [BOT] BotStartedSpeaking ↑")

        elif isinstance(frame, BotStoppedSpeakingFrame) and direction == FrameDirection.UPSTREAM:
            logger.info("🔕 [BOT] BotStoppedSpeaking ↑ (upstream)")

        await self.push_frame(frame, direction)


class AiTranscriptPoster(FrameProcessor):
    """
    Placed between GroqLLMService and EdgeTTSService.

    1. Accumulates LLMTextFrame chunks from the LLM.
       On LLMFullResponseEndFrame:
         - POSTs the complete (user, AI) turn pair to Node for evaluation.
         - Sends the full ai_transcript to Flutter for history storage.
         - Streams karaoke word-chunks to Flutter so words appear on screen in
           sync with the audio (3 words per chunk to fill 2-3 visible lines
           before being replaced by the next batch).
    2. Catches BotStoppedSpeakingFrame flowing upstream and sends "ai_done"
       so Flutter knows the AI has finished speaking.

    All frames are passed through unchanged.
    """

    # Send one word at a time so Flutter can accumulate and wrap naturally.
    # Flutter decides when to clear and start a new "page" based on word count.
    _KARAOKE_CHUNK_WORDS = 1

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
                # Normalise for display (same transformations applied to TTS input).
                display_text = _normalise_tts(ai_text)
                # Full text — Flutter stores this for history / evaluation only.
                asyncio.create_task(
                    self._transport.send_message(
                        json.dumps({"type": "ai_transcript", "text": display_text})
                    ),
                    name="ui-ai-transcript",
                )
                # Karaoke stream: split into N-word chunks and send sequentially.
                asyncio.create_task(
                    self._stream_karaoke(display_text),
                    name="ui-karaoke",
                )

        elif isinstance(frame, BotStoppedSpeakingFrame) and direction == FrameDirection.UPSTREAM:
            # Bot finished playing audio — signal Flutter to return to user-turn state.
            asyncio.create_task(
                self._transport.send_message(json.dumps({"type": "ai_done"})),
                name="ui-ai-done",
            )

        await self.push_frame(frame, direction)

    async def _stream_karaoke(self, text: str) -> None:
        """
        Split text into word-chunks and send them to Flutter with a small
        delay between each so the text scrolls in rough sync with TTS playback.

        Timing heuristic: ~140 words/minute at +20% speed ≈ 0.43 s per word.
        We send each chunk just before the TTS would finish reading it so the
        next batch is already on screen when the voice moves on.
        """
        words = text.split()
        if not words:
            return
        chunk_size = self._KARAOKE_CHUNK_WORDS
        # Approximate seconds per word at the sped-up TTS rate.
        secs_per_word = 0.40
        delay = chunk_size * secs_per_word  # seconds between chunk sends

        for i in range(0, len(words), chunk_size):
            chunk = " ".join(words[i: i + chunk_size])
            try:
                await self._transport.send_message(
                    json.dumps({"type": "ai_karaoke", "text": chunk})
                )
            except Exception as exc:
                logger.warning("Karaoke send error: %s", exc)
            if i + chunk_size < len(words):
                await asyncio.sleep(delay)

    async def _post_turn(self, user_transcript: str, ai_transcript: str) -> None:
        """
        POST the completed turn pair to Node for Firestore persistence.

        Retries up to _MAX_RETRIES times with exponential backoff on network
        errors or 5xx responses.  4xx errors (bad request, session not found,
        unauthorised) are not retried — they indicate a logic error.
        """
        url = f"{NODE_BACKEND_URL}/sessions/internal/live-voice-turn"
        payload = {
            "sessionId": self._session_id,
            "userTranscript": user_transcript,
            "aiTranscript": ai_transcript,
        }
        headers = {"X-Communiq-Worker-Secret": PIPECAT_WEBHOOK_SECRET}

        _MAX_RETRIES = 3
        _BASE_DELAY  = 1.0  # seconds; doubles each attempt

        for attempt in range(1, _MAX_RETRIES + 1):
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    resp = await client.post(url, json=payload, headers=headers)

                if resp.status_code in (200, 201):
                    logger.info(
                        "[%s] Turn synced (attempt %d) — user=%d chars, ai=%d chars",
                        self._session_id, attempt,
                        len(user_transcript), len(ai_transcript),
                    )
                    return

                # 4xx — don't retry (bad request, auth, session gone)
                if 400 <= resp.status_code < 500:
                    logger.warning(
                        "[%s] live-voice-turn POST returned %d (not retrying): %s",
                        self._session_id, resp.status_code, resp.text[:300],
                    )
                    return

                # 5xx — retryable
                logger.warning(
                    "[%s] live-voice-turn POST returned %d (attempt %d/%d)",
                    self._session_id, resp.status_code, attempt, _MAX_RETRIES,
                )

            except Exception as exc:
                logger.warning(
                    "[%s] live-voice-turn network error (attempt %d/%d): %s",
                    self._session_id, attempt, _MAX_RETRIES, exc,
                )

            if attempt < _MAX_RETRIES:
                await asyncio.sleep(_BASE_DELAY * (2 ** (attempt - 1)))

        logger.error(
            "[%s] Failed to sync turn after %d attempts — turn lost.",
            self._session_id, _MAX_RETRIES,
        )


# ─── Session duration cap ─────────────────────────────────────────────────────


async def _enforce_session_timeout(session_id: str, task: PipelineTask) -> None:
    """
    Runs alongside the pipeline task for the lifetime of the session. If the
    session is still active after SESSION_MAX_DURATION_SECONDS, force-ends the
    pipeline (via EndFrame, same mechanism as on_participant_left) regardless
    of participant activity. Cancelled by the caller as soon as the session
    ends normally so it never fires after a clean shutdown.
    """
    try:
        await asyncio.sleep(SESSION_MAX_DURATION_SECONDS)
    except asyncio.CancelledError:
        return
    logger.warning(
        "[%s] Session hit hard duration cap (%ds) — force-ending pipeline "
        "(timeout, NOT a normal participant-left end).",
        session_id,
        SESSION_MAX_DURATION_SECONDS,
    )
    await task.queue_frame(EndFrame())


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
                # Permissive values for debugging — emulator mic can be very quiet.
                # confidence: 0.4 lets Silero fire even on faint speech.
                # min_volume: 0.02 is near-zero RMS gate (won't block quiet mics).
                # start_secs: 0.2 s to fire quickly.
                # stop_secs: 0.8 s pause before treating as silence.
                confidence=0.4,
                min_volume=0.02,
                start_secs=0.2,
                stop_secs=0.8,
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
            # Groq retired llama-3.1-*; see ai-server/app/config.py.
            model=os.getenv("GROQ_LLM_MODEL", "openai/gpt-oss-20b"),
            # 320 tokens allows ~4 spoken sentences on a detailed answer
            # while the voice_suffix instruction prevents unnecessary padding
            # on short user inputs.
            max_completion_tokens=320,
            temperature=0.75,
        ),
    )

    # ── TTS ───────────────────────────────────────────────────────────────────
    # Using Microsoft Edge TTS (free, no rate limits).
    # Rate is set to +20% via _EDGE_TTS_RATE (overridable via EDGE_TTS_RATE env var).
    tts = EdgeTTSService(voice=_EDGE_TTS_VOICE, rate=_EDGE_TTS_RATE)

    # ── Context (chat history) ────────────────────────────────────────────────
    # Voice-mode instruction: teaches the LLM to match response length to
    # what the user actually said — a one-liner deserves a one-liner back,
    # a detailed answer deserves a fuller response. No markdown ever.
    voice_suffix = (
        "\n\nVoice mode rules (strictly follow):\n"
        "1. Never use bullet points, numbered lists, asterisks, or any markdown.\n"
        "2. Match your reply length to the user's input:\n"
        "   - Short input (greeting, one-word, yes/no) → 1 sentence reply, then ask one question.\n"
        "   - Medium input (1–2 sentences) → 2–3 sentence reply.\n"
        "   - Detailed input (paragraph, full explanation) → up to 4 sentences, but still conversational.\n"
        "3. Never monologue. Always end with a question or a clear invitation to continue.\n"
        "4. Speak naturally — contractions, natural rhythm — as if talking on a phone call.\n"
        "5. Do NOT re-introduce yourself after the opening line."
    )
    messages: list[dict] = [{"role": "system", "content": system_prompt + voice_suffix}]
    # Seed the opening line so the bot knows what it already said.
    # Without this the LLM starts with an empty context and re-introduces itself.
    if opening_text and opening_text.strip():
        messages.append({"role": "assistant", "content": opening_text.strip()})
        logger.info("[%s] Seeded opening into LLM context (%d chars)", session_id, len(opening_text))
    context = LLMContext(messages=messages)

    # Smart Turn is Pipecat's neural end-of-turn detector. Without explicit
    # configuration it defaults to stop_secs=3.0 — the user would have to be
    # silent for 3 full seconds before the bot responds.  We override to 0.8 s
    # which matches our Silero stop_secs and gives a natural conversational pace.
    _smart_turn = LocalSmartTurnAnalyzerV3(
        params=SmartTurnParams(
            stop_secs=0.8,
            pre_speech_ms=200.0,
        )
    )
    context_aggregator = LLMContextAggregatorPair(
        context,
        user_params=LLMUserAggregatorParams(
            user_turn_strategies=UserTurnStrategies(
                stop=[TurnAnalyzerUserTurnStopStrategy(turn_analyzer=_smart_turn)]
            )
        ),
    )

    # ── Turn-sync + UI-sync processors ───────────────────────────────────────
    turn_state = _TurnState()
    user_capture = UserTranscriptCapture(state=turn_state, transport=transport)
    ai_poster = AiTranscriptPoster(session_id=session_id, state=turn_state, transport=transport)
    vad_debug = VadDebugLogger()

    # ── Pipeline ──────────────────────────────────────────────────────────────
    #
    #  transport.input   — WebRTC audio frames from Flutter mic
    #  vad               — SileroVAD: emits UserStarted/StoppedSpeakingFrame
    #  vad_debug         — logs VAD events for debugging (pass-through)
    #  stt               — Groq Whisper: segments on VAD events → TranscriptionFrame
    #  user_capture      — records TranscriptionFrame.text in turn_state
    #  context_agg.user  — adds transcription into LLM message history
    #  llm               — Groq Llama: streams LLMTextFrame + LLMFullResponseEndFrame
    #  ai_poster         — collects LLMTextFrames, POSTs turn pair to Node
    #  tts               — Edge TTS: text → audio frames
    #  transport.output  — sends audio frames back to Flutter via WebRTC
    #  context_agg.asst  — adds the AI reply to LLM message history
    #
    pipeline = Pipeline(
        [
            transport.input(),
            vad,
            vad_debug,
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

    # Hard session-duration cap — see _enforce_session_timeout. Runs for the
    # whole pipeline lifetime; cancelled below once the session ends any other
    # way so it can never fire after a clean shutdown.
    timeout_task = asyncio.create_task(
        _enforce_session_timeout(session_id, task),
        name=f"session-timeout-{session_id}",
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
            "[%s] Participant left (%s) — sending EndFrame to pipeline "
            "(normal end, before the %ds duration cap).",
            session_id,
            reason,
            SESSION_MAX_DURATION_SECONDS,
        )
        timeout_task.cancel()
        await task.queue_frame(EndFrame())

    # ── Run ───────────────────────────────────────────────────────────────────
    runner = PipelineRunner()
    try:
        await runner.run(task)
    finally:
        timeout_task.cancel()
        logger.info("[%s] Bot pipeline finished.", session_id)
