from pydantic import BaseModel, field_validator


class OpeningRequest(BaseModel):
    """JSON body for POST /session/opening — AI speaks first (no user audio)."""

    sessionId: str
    systemPrompt: str

    @field_validator("systemPrompt")
    @classmethod
    def validate_system_prompt(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("systemPrompt must not be empty.")
        return v


class OpeningResponse(BaseModel):
    """Response from POST /session/opening — matches Node opening route."""

    aiReply: str
    aiAudioBase64: str


class TurnResponse(BaseModel):
    """
    Response from POST /session/turn.
    Matches the shape Node's fastApiService.sendTurnToFastApi() expects.
    """
    userTranscript: str
    aiReply: str
    aiAudioBase64: str


class EvaluateResponse(BaseModel):
    """
    Response from POST /session/evaluate.
    Matches the shape Node's fastApiService.evaluateSession() expects
    and what sessionController writes to Firestore evaluationReports.
    """
    scores: dict[str, int]       # { clarity, fluency, confidence, vocabulary, grammar, pronunciation } — 0-100
    fillerWordCount: int
    fillerWords: list[str]
    strengths: list[str]         # exactly 2 items
    improvements: list[str]      # exactly 2 items
    recommendedNextType: str


class EvaluateRequest(BaseModel):
    """
    Request body for POST /session/evaluate.
    Matches what Node's fastApiService.evaluateSession() sends.
    """
    sessionId: str
    fullTranscript: str
    scenarioType: str

    @field_validator("fullTranscript")
    @classmethod
    def validate_transcript(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("fullTranscript must not be empty.")
        if len(v) > 20_000:
            raise ValueError(
                f"Transcript too long ({len(v)} chars). Maximum is 20,000 characters."
            )
        return v

    @field_validator("scenarioType")
    @classmethod
    def validate_scenario_type(cls, v: str) -> str:
        v = v.strip().lower()
        if not v:
            raise ValueError("scenarioType must not be empty.")
        return v
