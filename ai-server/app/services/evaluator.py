import json
import re

REQUIRED_SCORE_KEYS = {"clarity", "fluency", "confidence", "vocabulary", "grammar", "pronunciation"}
LEARNING_SCORE_KEYS = {"accuracy", "depth", "clarity", "examples"}
CONTEST_SCORE_KEYS  = {"argumentation", "evidence", "rebuttal", "delivery"}

# Matches scenarioType_level format e.g. hr_interview_intermediate, sales_advanced
_RECOMMENDED_NEXT_PATTERN = re.compile(r"^[a-z][a-z0-9_]*_[a-z]+$")


def parse_evaluation(raw: str) -> dict:
    """
    Extract and validate the evaluation JSON from raw LLM output.

    - Strips markdown fences and surrounding prose.
    - Coerces float scores to int (LLMs sometimes return 72.5 instead of 72).
    - Validates all required fields and ranges.
    - Returns a dict with snake_case keys — the endpoint maps them to camelCase
      before returning to Node.

    Raises ValueError with a clear message if the schema is not met.
    """
    cleaned = _strip_fences(raw.strip())
    cleaned = _extract_json_object(cleaned)

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(
            f"LLM did not return valid JSON.\nError: {e}\nRaw output:\n{raw}"
        ) from e

    _coerce_scores(data)
    _validate(data)
    return data


# ─── Extraction helpers ───────────────────────────────────────────────────────

def _strip_fences(text: str) -> str:
    text = re.sub(r"^```[a-zA-Z]*\s*\n?", "", text)
    text = re.sub(r"\n?```\s*$", "", text)
    return text.strip()


def _extract_json_object(text: str) -> str:
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError(
            "No JSON object found in LLM evaluation output. "
            "The model may have returned plain text instead of JSON."
        )
    return text[start : end + 1]


# ─── Coercion ─────────────────────────────────────────────────────────────────

def _coerce_scores(data: dict) -> None:
    """
    LLMs sometimes return float scores (e.g. 72.5) or string numbers ("80").
    Round and clamp to int in range 0–100 rather than hard-failing.
    """
    scores = data.get("scores")
    if not isinstance(scores, dict):
        return
    for key in REQUIRED_SCORE_KEYS:
        val = scores.get(key)
        if isinstance(val, float):
            scores[key] = max(0, min(100, round(val)))
        elif isinstance(val, str):
            try:
                scores[key] = max(0, min(100, round(float(val))))
            except (ValueError, TypeError):
                pass
        elif isinstance(val, int):
            scores[key] = max(0, min(100, val))


# ─── Validation ───────────────────────────────────────────────────────────────

def _validate(data: dict) -> None:
    if not isinstance(data, dict):
        raise ValueError("Evaluation output must be a JSON object.")

    # scores
    scores = data.get("scores")
    if not isinstance(scores, dict):
        raise ValueError("Missing or invalid 'scores' field — must be an object.")

    missing = REQUIRED_SCORE_KEYS - scores.keys()
    if missing:
        raise ValueError(f"Missing score keys: {sorted(missing)}")

    for key in REQUIRED_SCORE_KEYS:
        val = scores[key]
        if not isinstance(val, int) or not (0 <= val <= 100):
            raise ValueError(
                f"Score '{key}' must be an integer between 0 and 100, got: {val!r}"
            )

    # filler_words
    if not isinstance(data.get("filler_words"), list):
        raise ValueError("'filler_words' must be a list.")

    # filler_count
    fc = data.get("filler_count")
    if not isinstance(fc, int) or fc < 0:
        raise ValueError(f"'filler_count' must be a non-negative integer, got: {fc!r}")

    # strengths — clamp/pad to exactly 2 rather than hard-failing
    strengths = data.get("strengths")
    if not isinstance(strengths, list):
        strengths = []
    strengths = [s for s in strengths if isinstance(s, str) and s.strip()]
    while len(strengths) < 2:
        strengths.append("Maintained engagement throughout the session.")
    data["strengths"] = strengths[:2]

    # improvements — clamp/pad to exactly 2 rather than hard-failing
    improvements = data.get("improvements")
    if not isinstance(improvements, list):
        improvements = []
    improvements = [s for s in improvements if isinstance(s, str) and s.strip()]
    while len(improvements) < 2:
        improvements.append("Focus on reducing filler words and speaking at a measured pace.")
    data["improvements"] = improvements[:2]

    # recommended_next — sanitize rather than hard-fail so a non-compliant LLM
    # response never prevents the user from seeing their evaluation results.
    rec = data.get("recommended_next")
    if isinstance(rec, str) and rec.strip():
        # Normalise: lowercase, replace hyphens/spaces with underscores, strip edges
        rec = re.sub(r"[\s\-]+", "_", rec.strip().lower())
        rec = re.sub(r"[^a-z0-9_]", "", rec)
    if not isinstance(rec, str) or not rec.strip() or not _RECOMMENDED_NEXT_PATTERN.match(rec):
        rec = "general_intermediate"
    data["recommended_next"] = rec


# ─── Learning module parser ───────────────────────────────────────────────────

def parse_learning_evaluation(raw: str) -> dict:
    """
    Extract and validate the learning evaluation JSON from raw LLM output.

    Expected schema:
        scores: { accuracy, depth, clarity, examples }  (int 0-100)
        overall_score: int
        strengths: [str, str]
        improvements: [str, str]
        feedback: str
    """
    cleaned = _strip_fences(raw.strip())
    cleaned = _extract_json_object(cleaned)

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(
            f"LLM did not return valid JSON.\nError: {e}\nRaw output:\n{raw}"
        ) from e

    _coerce_scores_for_keys(data, LEARNING_SCORE_KEYS)
    _validate_common(data, LEARNING_SCORE_KEYS)
    _validate_overall_score(data, LEARNING_SCORE_KEYS)
    _validate_feedback(data)
    return data


# ─── Contest parser ───────────────────────────────────────────────────────────

def parse_contest_evaluation(raw: str) -> dict:
    """
    Extract and validate the contest evaluation JSON from raw LLM output.

    Expected schema:
        scores: { argumentation, evidence, rebuttal, delivery }  (int 0-100)
        overall_score: int
        strengths: [str, str]
        improvements: [str, str]
        feedback: str
    """
    cleaned = _strip_fences(raw.strip())
    cleaned = _extract_json_object(cleaned)

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise ValueError(
            f"LLM did not return valid JSON.\nError: {e}\nRaw output:\n{raw}"
        ) from e

    _coerce_scores_for_keys(data, CONTEST_SCORE_KEYS)
    _validate_common(data, CONTEST_SCORE_KEYS)
    _validate_overall_score(data, CONTEST_SCORE_KEYS)
    _validate_feedback(data)
    return data


# ─── Shared helpers for the new parsers ───────────────────────────────────────

def _coerce_scores_for_keys(data: dict, keys: set[str]) -> None:
    """Same float→int coercion logic as _coerce_scores but for an arbitrary key set."""
    scores = data.get("scores")
    if not isinstance(scores, dict):
        return
    for key in keys:
        val = scores.get(key)
        if isinstance(val, float):
            scores[key] = max(0, min(100, round(val)))
        elif isinstance(val, str):
            try:
                scores[key] = max(0, min(100, round(float(val))))
            except (ValueError, TypeError):
                pass
        elif isinstance(val, int):
            scores[key] = max(0, min(100, val))


def _validate_common(data: dict, required_keys: set[str]) -> None:
    """Validate scores dict, strengths, and improvements for learning/contest schemas."""
    if not isinstance(data, dict):
        raise ValueError("Evaluation output must be a JSON object.")

    scores = data.get("scores")
    if not isinstance(scores, dict):
        raise ValueError("Missing or invalid 'scores' field — must be an object.")

    missing = required_keys - scores.keys()
    if missing:
        raise ValueError(f"Missing score keys: {sorted(missing)}")

    for key in required_keys:
        val = scores[key]
        if not isinstance(val, int) or not (0 <= val <= 100):
            raise ValueError(
                f"Score '{key}' must be an integer between 0 and 100, got: {val!r}"
            )

    # strengths — clamp/pad to exactly 2
    strengths = data.get("strengths")
    if not isinstance(strengths, list):
        strengths = []
    strengths = [s for s in strengths if isinstance(s, str) and s.strip()]
    while len(strengths) < 2:
        strengths.append("Demonstrated engagement with the topic throughout.")
    data["strengths"] = strengths[:2]

    # improvements — clamp/pad to exactly 2
    improvements = data.get("improvements")
    if not isinstance(improvements, list):
        improvements = []
    improvements = [s for s in improvements if isinstance(s, str) and s.strip()]
    while len(improvements) < 2:
        improvements.append("Focus on adding specific examples to support your points.")
    data["improvements"] = improvements[:2]


def _validate_overall_score(data: dict, keys: set[str]) -> None:
    """Compute or validate overall_score as the integer mean of the scores."""
    scores = data.get("scores", {})
    computed = round(sum(scores.get(k, 0) for k in keys) / len(keys))
    raw_overall = data.get("overall_score")
    if not isinstance(raw_overall, int) or not (0 <= raw_overall <= 100):
        data["overall_score"] = computed
    else:
        data["overall_score"] = max(0, min(100, raw_overall))


def _validate_feedback(data: dict) -> None:
    """Ensure feedback is a non-empty string; fall back to a generic message."""
    feedback = data.get("feedback")
    if not isinstance(feedback, str) or not feedback.strip():
        data["feedback"] = "Keep practising to build your skills further."
    else:
        data["feedback"] = feedback.strip()
