"""
Post live-voice transcripts to Node so Firestore matches HTTP /sessions/turn.

Requires NODE_INTERNAL_URL and PIPECAT_WEBHOOK_SECRET (same as server/.env).
"""

from __future__ import annotations

import logging
from typing import Optional

import httpx
from pipecat.frames.frames import (
    Frame,
    InterruptionFrame,
    LLMFullResponseEndFrame,
    TextFrame,
    TranscriptionFrame,
)
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

logger = logging.getLogger("communiq.pipecat.sync")


async def _post_turn(
    base_url: str,
    secret: str,
    session_id: str,
    *,
    user: Optional[str] = None,
    ai: Optional[str] = None,
) -> None:
    url = f"{base_url.rstrip('/')}/sessions/internal/live-voice-turn"
    payload: dict = {"sessionId": session_id}
    if user is not None and user.strip():
        payload["userTranscript"] = user.strip()
    if ai is not None and ai.strip():
        payload["aiTranscript"] = ai.strip()
    if len(payload) == 1:
        return
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            r = await client.post(
                url,
                json=payload,
                headers={"X-Communiq-Worker-Secret": secret},
            )
            r.raise_for_status()
        logger.info(
            "Synced live-voice turn to Node — session=%s keys=%s",
            session_id,
            list(payload.keys()),
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning("Live-voice Firestore sync failed: %s", exc)


class LiveVoiceUserSyncProcessor(FrameProcessor):
    """After STT: POST final user transcript to Node."""

    def __init__(
        self,
        *,
        session_id: str,
        node_base_url: str,
        webhook_secret: str,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._session_id = session_id
        self._node_base_url = node_base_url
        self._secret = webhook_secret

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        if direction == FrameDirection.DOWNSTREAM and isinstance(
            frame, TranscriptionFrame
        ):
            await _post_turn(
                self._node_base_url,
                self._secret,
                self._session_id,
                user=frame.text,
            )
        await self.push_frame(frame, direction)


class LiveVoiceAssistantSyncProcessor(FrameProcessor):
    """After LLM: buffer TextFrame tokens; on LLMFullResponseEndFrame POST AI reply."""

    def __init__(
        self,
        *,
        session_id: str,
        node_base_url: str,
        webhook_secret: str,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self._session_id = session_id
        self._node_base_url = node_base_url
        self._secret = webhook_secret
        self._buf: list[str] = []

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)
        if direction == FrameDirection.DOWNSTREAM:
            if isinstance(frame, InterruptionFrame):
                self._buf.clear()
            elif isinstance(frame, TextFrame) and not isinstance(
                frame, TranscriptionFrame
            ):
                self._buf.append(frame.text)
            elif isinstance(frame, LLMFullResponseEndFrame):
                text = "".join(self._buf).strip()
                self._buf.clear()
                if text:
                    await _post_turn(
                        self._node_base_url,
                        self._secret,
                        self._session_id,
                        ai=text,
                    )
        await self.push_frame(frame, direction)
