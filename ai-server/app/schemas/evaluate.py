from typing import Optional

from pydantic import BaseModel, field_validator


# ─── Roleplay ─────────────────────────────────────────────────────────────────
# These mirror EvaluateRequest / EvaluateResponse in session.py exactly so the
# /evaluate/roleplay endpoint can replace /session/evaluate without any Node changes.

class RoleplayEvaluateRequest(BaseModel):
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


class RoleplayEvaluateResponse(BaseModel):
    scores: dict[str, int]       # clarity, fluency, confidence, vocabulary, grammar, pronunciation
    fillerWordCount: int
    fillerWords: list[str]
    strengths: list[str]         # exactly 2 items
    improvements: list[str]      # exactly 2 items
    recommendedNextType: str


# ─── Learning module ──────────────────────────────────────────────────────────

class LearningEvaluateRequest(BaseModel):
    """
    Evaluate a user's answer to a learning module question.

    Fields:
        sessionId         — learning session or attempt UUID (for logging)
        question          — the question or prompt that was shown to the user
        userAnswer        — the user's text answer
        topic             — topic area e.g. "public speaking", "active listening"
        difficulty        — "beginner" | "intermediate" | "advanced"
        expectedKeyPoints — optional list of points the ideal answer should cover
    """
    sessionId: str
    question: str
    userAnswer: str
    topic: str
    difficulty: str
    expectedKeyPoints: list[str] = []

    @field_validator("userAnswer")
    @classmethod
    def validate_answer(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("userAnswer must not be empty.")
        if len(v) > 5_000:
            raise ValueError(
                f"Answer too long ({len(v)} chars). Maximum is 5,000 characters."
            )
        return v

    @field_validator("difficulty")
    @classmethod
    def validate_difficulty(cls, v: str) -> str:
        v = v.strip().lower()
        allowed = {"beginner", "intermediate", "advanced"}
        if v not in allowed:
            raise ValueError(f"difficulty must be one of {sorted(allowed)}.")
        return v


class LearningEvaluateResponse(BaseModel):
    """
    scores keys: accuracy, depth, clarity, examples  (0-100 each)
    overallScore: mean of the four scores
    feedback: 2–3 sentence holistic comment
    """
    scores: dict[str, int]
    overallScore: int
    strengths: list[str]         # exactly 2 items
    improvements: list[str]      # exactly 2 items
    feedback: str


# ─── Contest ──────────────────────────────────────────────────────────────────

class ContestEvaluateRequest(BaseModel):
    """
    Evaluate a user's spoken/written contribution in a contest (debate, GD, quiz).

    Fields:
        sessionId   — contest session UUID (for logging)
        userAnswer  — the user's contribution (transcript or written answer)
        contestType — "debate" | "gd" | "extempore" | "quiz"
        motion      — the debate topic, GD topic, or quiz question
        position    — "for" | "against" | "" (not applicable for GD/extempore)
    """
    sessionId: str
    userAnswer: str
    contestType: str
    motion: str
    position: Optional[str] = ""

    @field_validator("userAnswer")
    @classmethod
    def validate_answer(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("userAnswer must not be empty.")
        if len(v) > 10_000:
            raise ValueError(
                f"Answer too long ({len(v)} chars). Maximum is 10,000 characters."
            )
        return v

    @field_validator("contestType")
    @classmethod
    def validate_contest_type(cls, v: str) -> str:
        v = v.strip().lower()
        allowed = {"debate", "gd", "extempore", "quiz"}
        if v not in allowed:
            raise ValueError(f"contestType must be one of {sorted(allowed)}.")
        return v


class ContestEvaluateResponse(BaseModel):
    """
    scores keys: argumentation, evidence, rebuttal, delivery  (0-100 each)
    overallScore: mean of the four scores
    feedback: 2–3 sentence holistic comment
    """
    scores: dict[str, int]
    overallScore: int
    strengths: list[str]         # exactly 2 items
    improvements: list[str]      # exactly 2 items
    feedback: str


# ─── Visual Analysis Evaluation ───────────────────────────────────────────────

class VisualInsightSchema(BaseModel):
    type: str  # "positive" | "suggestion" | "warning"
    title: str
    description: str


class VisualEvaluateRequest(BaseModel):
    eyeContactPercentage: float
    gazeStabilityPercentage: float
    spineAlignmentPercentage: float
    shoulderSymmetryPercentage: float
    chestOpennessPercentage: float
    headTiltStabilityPercentage: float
    handMovementPercentage: float
    overallPostureScore: int


class VisualEvaluateResponse(BaseModel):
    insights: list[VisualInsightSchema]

