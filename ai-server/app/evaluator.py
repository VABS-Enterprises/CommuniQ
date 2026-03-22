import json
import math
import re

REQUIRED_SCORE_KEYS = {"clarity", "fluency", "confidence", "vocabulary", "grammar"}

_RECOMMENDED_NEXT_PATTERN = re.compile(r"^[a-z][a-z0-9_]*_[a-z]+$")


def parse_evaluation(raw: str) -> dict:
    """
    Extract and validate the evaluation JSON from raw LLM output.
    - Strips markdown fences and leading/trailing prose.
    - Coerces float scores to int (LLMs sometimes return 7.5 instead of 7).
    - Raises ValueError with a clear message if schema is not met.
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
    LLMs sometimes return float scores (e.g. 7.5). Round and convert to int
    rather than hard-failing, since the intent is clear.
    """
    scores = data.get("scores")
    if not isinstance(scores, dict):
        return
    for key in REQUIRED_SCORE_KEYS:
        val = scores.get(key)
        if isinstance(val, float):
            scores[key] = max(1, min(10, round(val)))
        elif isinstance(val, str):
            try:
                scores[key] = max(1, min(10, round(float(val))))
            except (ValueError, TypeError):
                pass


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
        if not isinstance(val, int) or not (1 <= val <= 10):
            raise ValueError(
                f"Score '{key}' must be an integer between 1 and 10, got: {val!r}"
            )

    # filler_words
    if not isinstance(data.get("filler_words"), list):
        raise ValueError("'filler_words' must be a list.")

    # filler_count
    fc = data.get("filler_count")
    if not isinstance(fc, int) or fc < 0:
        raise ValueError(f"'filler_count' must be a non-negative integer, got: {fc!r}")

    # strengths
    strengths = data.get("strengths")
    if not isinstance(strengths, list) or len(strengths) != 2:
        raise ValueError(
            f"'strengths' must be a list of exactly 2 items, got: {strengths!r}"
        )
    for i, s in enumerate(strengths):
        if not isinstance(s, str) or not s.strip():
            raise ValueError(f"'strengths[{i}]' must be a non-empty string.")

    # improvements
    improvements = data.get("improvements")
    if not isinstance(improvements, list) or len(improvements) != 2:
        raise ValueError(
            f"'improvements' must be a list of exactly 2 items, got: {improvements!r}"
        )
    for i, s in enumerate(improvements):
        if not isinstance(s, str) or not s.strip():
            raise ValueError(f"'improvements[{i}]' must be a non-empty string.")

    # recommended_next
    rec = data.get("recommended_next")
    if not isinstance(rec, str) or not rec.strip():
        raise ValueError("'recommended_next' must be a non-empty string.")
    if not _RECOMMENDED_NEXT_PATTERN.match(rec.strip()):
        raise ValueError(
            f"'recommended_next' must follow the format 'scenario_level' "
            f"(e.g. 'hr_interview_intermediate'), got: {rec!r}"
        )
