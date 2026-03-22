# Maps Node's scenarioType values to human-readable descriptions
# injected into the evaluator prompt for context-aware feedback.
SCENARIO_TYPE_DESCRIPTIONS: dict[str, str] = {
    "hr_interview": "an HR behavioral interview at an Indian tech company",
    "technical":    "a technical panel interview covering projects and system design",
    "gd":           "a structured group discussion with a professional moderator",
    "sales":        "a B2B sales call with a skeptical Indian client",
}

_DEFAULT_SCENARIO_DESCRIPTION = "a professional spoken English practice session"

_SCORING_RUBRIC = """
SCORING GUIDE — use the full 0–100 range, do not cluster around 50–70:

CLARITY — How precisely and directly did the user express their ideas?
  90–100: Ideas are crisp, well-structured, zero ambiguity
  70–89:  Mostly clear, minor lapses in organisation
  50–69:  Understandable but requires some effort to follow
  30–49:  Frequently unclear, incomplete thoughts
  0–29:   Barely comprehensible

FLUENCY — Natural rhythm, absence of unnatural pauses, repetitions, or restarts
  90–100: Completely smooth, natural conversational flow
  70–89:  Mostly smooth with occasional minor hesitations
  50–69:  Noticeable pauses or repetitions but manageable
  30–49:  Frequent interruptions in flow, distracting
  0–29:   Very choppy, difficult to follow as spoken speech

CONFIDENCE — Assertiveness, conviction, absence of hedging
  90–100: Sounds genuinely self-assured, answers without hedging
  70–89:  Generally confident with minor uncertainty
  50–69:  Mixes confident and hesitant moments
  30–49:  Frequently hedges, trails off, or sounds unsure
  0–29:   Sounds very anxious, heavily qualifies everything

VOCABULARY — Range, precision, and appropriateness of word choice
  90–100: Rich, varied, precise vocabulary for the context
  70–89:  Good word choice with occasional imprecision
  50–69:  Adequate but repetitive or generic vocabulary
  30–49:  Limited range, frequent misuse of words
  0–29:   Very restricted vocabulary, many wrong word choices

GRAMMAR — Correctness and structure of spoken sentences
  90–100: Grammatically correct, well-formed sentences
  70–89:  Minor errors that do not impede understanding
  50–69:  Noticeable errors but generally comprehensible
  30–49:  Frequent errors that impede understanding
  0–29:   Severe grammatical breakdown throughout
"""

_FILLER_WORD_LIST = (
    "um, uh, like, you know, basically, actually, literally, right, so, kind of, "
    "sort of, I mean, you see, well, okay so, yeah so, honestly, obviously, clearly"
)

_EVALUATION_JSON_SCHEMA = """{
  "scores": {
    "clarity":    <int 0-100>,
    "fluency":    <int 0-100>,
    "confidence": <int 0-100>,
    "vocabulary": <int 0-100>,
    "grammar":    <int 0-100>
  },
  "filler_words": ["<word>", "<word>"],
  "filler_count": <int — total occurrences across the transcript>,
  "strengths": [
    "<specific strength observed in this session — not generic praise>",
    "<specific strength observed in this session — not generic praise>"
  ],
  "improvements": [
    "<specific, actionable improvement with an example of how to apply it>",
    "<specific, actionable improvement with an example of how to apply it>"
  ],
  "recommended_next": "<format: scenarioType_level e.g. hr_interview_intermediate>"
}"""


def build_evaluator_prompt(scenario_type: str) -> str:
    """
    Build the evaluation system prompt.
    scenarioType comes directly from Node (e.g. 'hr_interview', 'gd', 'sales', 'technical').
    The transcript is passed separately as the user message in the Groq call.
    """
    description = SCENARIO_TYPE_DESCRIPTIONS.get(
        scenario_type.lower().strip(),
        _DEFAULT_SCENARIO_DESCRIPTION,
    )

    return f"""You are an expert communication coach specialising in evaluating spoken English for Indian professionals and students.

SESSION CONTEXT:
- Scenario type: {scenario_type}
- Description: This was {description}.

YOUR TASK:
Read the full conversation transcript carefully. Evaluate ONLY the USER's turns — not the AI agent's turns.
The transcript was captured via automatic speech recognition (STT), so minor transcription artifacts
(missing punctuation, slight misspellings) are expected — do not penalise for these.

{_SCORING_RUBRIC}

FILLER WORDS TO DETECT:
{_FILLER_WORD_LIST}
Count every individual occurrence (e.g. "um" said 3 times = filler_count += 3).

STRENGTHS AND IMPROVEMENTS:
- strengths must be specific observations from THIS session — not generic praise.
  Bad:  "You communicated well."
  Good: "You used a concrete example with numbers when describing the project timeline."
- improvements must be specific and actionable with a clear example of how to apply them.
  Bad:  "Improve your fluency."
  Good: "Replace filler pauses with a brief silence — saying nothing is better than saying 'um' or 'like'."

OUTPUT FORMAT:
- Output ONLY a valid JSON object. No explanation, no preamble, no markdown fences.
- Do not include any text outside the JSON object.
- All scores must be integers between 0 and 100.
- strengths must have EXACTLY 2 items.
- improvements must have EXACTLY 2 items.
- recommended_next format: scenarioType_level (e.g. hr_interview_intermediate, sales_advanced)

Output this exact schema:
{_EVALUATION_JSON_SCHEMA}""".strip()
