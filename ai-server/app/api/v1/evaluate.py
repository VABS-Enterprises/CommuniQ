"""
Evaluation endpoints — canonical AI evaluation surface for all CommuniQ features.

Routes:
  POST /evaluate/roleplay   — evaluates a completed roleplay session transcript
  POST /evaluate/learning   — evaluates a user's answer to a learning module question
  POST /evaluate/contest    — evaluates a user's contribution in a debate/GD/extempore

Design notes:
  - /evaluate/roleplay is the canonical replacement for the legacy /session/evaluate.
    Node's fastApiService.js calls this path. /session/evaluate is kept as a
    deprecated alias that delegates here.
  - /evaluate/learning and /evaluate/contest are new; called by future Node
    controllers for those features.
  - All three use temperature=0.2 for deterministic, consistent scoring.
  - The pipecat-worker has no involvement here — evaluation is always batch/async.
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from groq import AsyncGroq

from app.core.prompts import (
    build_contest_evaluator_prompt,
    build_learning_evaluator_prompt,
    build_roleplay_evaluator_prompt,
)
from app.dependencies import get_groq_client, verify_internal_api_key
from app.schemas.evaluate import (
    ContestEvaluateRequest,
    ContestEvaluateResponse,
    LearningEvaluateRequest,
    LearningEvaluateResponse,
    RoleplayEvaluateRequest,
    RoleplayEvaluateResponse,
)
from app.services import llm_facade
from app.services.evaluator import (
    parse_contest_evaluation,
    parse_evaluation,
    parse_learning_evaluation,
)

logger = logging.getLogger("communiq.evaluate")

router = APIRouter(
    prefix="/evaluate",
    tags=["evaluate"],
    dependencies=[Depends(verify_internal_api_key)],
)


# ─── POST /evaluate/roleplay ──────────────────────────────────────────────────

@router.post("/roleplay", response_model=RoleplayEvaluateResponse)
async def evaluate_roleplay(
    req: RoleplayEvaluateRequest,
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Evaluate a completed roleplay session.

    Canonical replacement for the legacy POST /session/evaluate.
    Called by Node's fastApiService.evaluateSession() after a session ends.

    Accepts JSON: { sessionId, fullTranscript, scenarioType }
    Returns JSON: { scores, fillerWordCount, fillerWords, strengths, improvements, recommendedNextType }
    """
    system_prompt = build_roleplay_evaluator_prompt(req.scenarioType)

    logger.info(
        "Roleplay evaluation start — session=%s scenario=%s transcript=%d chars",
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
        logger.error("Roleplay evaluation LLM failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="Evaluation service unavailable. Please try again."
        ) from e

    raw = response.choices[0].message.content or ""

    try:
        result = parse_evaluation(raw)
    except ValueError as e:
        logger.error(
            "Roleplay evaluation parse failed — session=%s: %s\nRaw: %s",
            req.sessionId, e, raw[:500],
        )
        raise HTTPException(
            status_code=500, detail=f"Evaluation parsing failed: {e}"
        ) from e

    logger.info("Roleplay evaluation complete — session=%s", req.sessionId)

    return RoleplayEvaluateResponse(
        scores=result["scores"],
        fillerWordCount=result["filler_count"],
        fillerWords=result["filler_words"],
        strengths=result["strengths"],
        improvements=result["improvements"],
        recommendedNextType=result["recommended_next"],
    )


# ─── POST /evaluate/learning ──────────────────────────────────────────────────

@router.post("/learning", response_model=LearningEvaluateResponse)
async def evaluate_learning(
    req: LearningEvaluateRequest,
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Evaluate a user's answer to a learning module question.

    Accepts JSON: { sessionId, question, userAnswer, topic, difficulty, expectedKeyPoints? }
    Returns JSON: { scores, overallScore, strengths, improvements, feedback }

    scores keys: accuracy, depth, clarity, examples  (0–100 each)
    """
    system_prompt = build_learning_evaluator_prompt(
        topic=req.topic,
        difficulty=req.difficulty,
        expected_key_points=req.expectedKeyPoints,
    )

    logger.info(
        "Learning evaluation start — session=%s topic=%s difficulty=%s answer=%d chars",
        req.sessionId, req.topic, req.difficulty, len(req.userAnswer),
    )

    try:
        response = await llm_facade.eval_chat_completion(
            groq,
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": (
                        f"Question: {req.question}\n\n"
                        f"User's answer:\n{req.userAnswer}"
                    ),
                },
            ],
            max_tokens=768,
            temperature=0.2,
            timeout=40,
        )
    except Exception as e:
        logger.error("Learning evaluation LLM failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="Evaluation service unavailable. Please try again."
        ) from e

    raw = response.choices[0].message.content or ""

    try:
        result = parse_learning_evaluation(raw)
    except ValueError as e:
        logger.error(
            "Learning evaluation parse failed — session=%s: %s\nRaw: %s",
            req.sessionId, e, raw[:500],
        )
        raise HTTPException(
            status_code=500, detail=f"Evaluation parsing failed: {e}"
        ) from e

    logger.info("Learning evaluation complete — session=%s", req.sessionId)

    return LearningEvaluateResponse(
        scores=result["scores"],
        overallScore=result["overall_score"],
        strengths=result["strengths"],
        improvements=result["improvements"],
        feedback=result["feedback"],
    )


# ─── POST /evaluate/contest ───────────────────────────────────────────────────

@router.post("/contest", response_model=ContestEvaluateResponse)
async def evaluate_contest(
    req: ContestEvaluateRequest,
    groq: Optional[AsyncGroq] = Depends(get_groq_client),
):
    """
    Evaluate a user's contribution in a contest (debate, GD, extempore, quiz).

    Accepts JSON: { sessionId, userAnswer, contestType, motion, position? }
    Returns JSON: { scores, overallScore, strengths, improvements, feedback }

    scores keys: argumentation, evidence, rebuttal, delivery  (0–100 each)
    """
    system_prompt = build_contest_evaluator_prompt(
        contest_type=req.contestType,
        motion=req.motion,
        position=req.position or "",
    )

    logger.info(
        "Contest evaluation start — session=%s type=%s motion=%r answer=%d chars",
        req.sessionId, req.contestType, req.motion[:60], len(req.userAnswer),
    )

    try:
        response = await llm_facade.eval_chat_completion(
            groq,
            messages=[
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": (
                        f"Motion / Topic: {req.motion}\n"
                        + (f"Position: {req.position}\n\n" if req.position else "\n")
                        + f"User's contribution:\n{req.userAnswer}"
                    ),
                },
            ],
            max_tokens=768,
            temperature=0.2,
            timeout=40,
        )
    except Exception as e:
        logger.error("Contest evaluation LLM failed — session=%s: %s", req.sessionId, e)
        raise HTTPException(
            status_code=502, detail="Evaluation service unavailable. Please try again."
        ) from e

    raw = response.choices[0].message.content or ""

    try:
        result = parse_contest_evaluation(raw)
    except ValueError as e:
        logger.error(
            "Contest evaluation parse failed — session=%s: %s\nRaw: %s",
            req.sessionId, e, raw[:500],
        )
        raise HTTPException(
            status_code=500, detail=f"Evaluation parsing failed: {e}"
        ) from e

    logger.info("Contest evaluation complete — session=%s", req.sessionId)

    return ContestEvaluateResponse(
        scores=result["scores"],
        overallScore=result["overall_score"],
        strengths=result["strengths"],
        improvements=result["improvements"],
        feedback=result["feedback"],
    )
