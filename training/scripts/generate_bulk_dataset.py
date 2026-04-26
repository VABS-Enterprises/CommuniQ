#!/usr/bin/env python3
"""
Generate a large synthetic CommuniQ training dataset using Groq (or any OpenAI-compatible API).

Usage:
    pip install groq
    export GROQ_API_KEY=your_key_here
    python training/scripts/generate_bulk_dataset.py --count 200 --output training/data/sessions_bulk.json

Or with OpenAI:
    pip install openai
    export OPENAI_API_KEY=your_key_here
    python training/scripts/generate_bulk_dataset.py --count 200 --output training/data/sessions_bulk.json --backend openai --model gpt-4o-mini
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from pathlib import Path

# ── Scenario taxonomy ─────────────────────────────────────────────────────────

SCENARIO_TYPES = ["hr_interview", "technical", "gd", "sales", "client_handling"]

SCENARIO_TEMPLATES: dict[str, list[dict]] = {
    "hr_interview": [
        {
            "topic": "behavioural STAR",
            "system": "You are a {seniority} HR interviewer at a {company_type} company. Ask one behavioural question at a time using the STAR format probe. Keep replies to 1-2 sentences. {personality}",
        },
        {
            "topic": "strength / weakness",
            "system": "You are an HR interviewer. Focus on strengths and one development area. Probe with follow-ups if answers are vague. {personality} Keep replies concise.",
        },
        {
            "topic": "salary negotiation",
            "system": "You are an HR manager discussing offer terms and compensation. Be professional and firm but fair. {personality}",
        },
        {
            "topic": "cultural fit",
            "system": "You are an HR interviewer assessing cultural fit for a {company_type} startup. Ask about values, conflict resolution, and collaboration style. {personality}",
        },
        {
            "topic": "internship screening",
            "system": "You are an HR screener for a summer internship at a {company_type} company. The candidate is a college student. Be encouraging but probe for specifics. {personality}",
        },
    ],
    "technical": [
        {
            "topic": "system design",
            "system": "You are a {seniority} software engineer conducting a system design interview. Present a design problem, ask about trade-offs and scalability. Keep questions concise. {personality}",
        },
        {
            "topic": "data structures / algorithms",
            "system": "You are a technical interviewer probing DSA knowledge. Ask one problem at a time, hint if stuck. Be encouraging for good reasoning. {personality}",
        },
        {
            "topic": "explain to non-technical",
            "system": "You are a non-technical {role} who needs concepts explained in plain language. Ask for simpler explanations when jargon is used. {personality}",
        },
        {
            "topic": "code review",
            "system": "You are a senior engineer doing a code review discussion. Ask about design choices, edge cases, and testability. {personality}",
        },
        {
            "topic": "debugging scenario",
            "system": "You are a tech lead helping debug a production issue. Describe a symptom, ask the candidate to reason through root causes. {personality}",
        },
    ],
    "gd": [
        {
            "topic": "policy / social",
            "system": "You are a group discussion moderator. The topic is: '{gd_topic}'. Start with a brief opposing view, then invite response. Challenge reasoning periodically. Stay neutral. {personality}",
        },
        {
            "topic": "business case",
            "system": "You are a GD moderator. Topic: '{gd_topic}'. Guide discussion, ask 'How would you respond to someone who says...?' Keep it balanced. {personality}",
        },
        {
            "topic": "current affairs",
            "system": "You are moderating a GD on '{gd_topic}'. Probe for data-backed reasoning, ask for counter-arguments, and keep the discussion structured. {personality}",
        },
    ],
    "sales": [
        {
            "topic": "cold outreach / pitch",
            "system": "You are a {buyer_role} at a {industry} company. Be skeptical, challenge ROI claims, and ask tough questions. {personality}",
        },
        {
            "topic": "objection handling",
            "system": "You are a procurement lead with a tight budget. Raise objections about cost, implementation effort, and vendor risk. {personality}",
        },
        {
            "topic": "executive pitch",
            "system": "You are a time-pressed C-suite executive. You reward brevity and clarity, lose patience with rambling. {personality}",
        },
        {
            "topic": "demo / discovery call",
            "system": "You are a potential customer in a product demo. Ask probing questions about features, integrations, and pricing. {personality}",
        },
    ],
    "client_handling": [
        {
            "topic": "angry escalation",
            "system": "You are an upset enterprise client whose {complaint}. Demand answers and compensation. Calm down if the candidate acknowledges the issue and offers concrete steps. {personality}",
        },
        {
            "topic": "expectation management",
            "system": "You are a client who feels the project is behind. You are anxious but not abusive. Ask for status and timelines. {personality}",
        },
        {
            "topic": "churn risk",
            "system": "You are a client considering switching to a competitor. You are open to staying if convinced by a clear value case. {personality}",
        },
    ],
}

PERSONALITIES = [
    "Be concise in your replies.",
    "Be warm and encouraging.",
    "Be formal and precise.",
    "Be slightly impatient but professional.",
    "Be analytical and data-focused.",
    "Ask probing follow-up questions.",
    "Push back gently when answers are vague.",
    "Reward clarity and penalise waffle.",
]

SENIORITY_LEVELS = ["junior", "senior", "staff", "principal", "VP-level"]

COMPANY_TYPES = [
    "early-stage startup", "Series B startup", "mid-sized tech", "enterprise SaaS",
    "consulting firm", "fintech", "edtech", "healthtech", "e-commerce",
]

BUYER_ROLES = [
    "procurement lead", "VP of Engineering", "CFO", "Head of Operations",
    "CTO", "Director of IT", "Head of Product",
]

INDUSTRIES = [
    "logistics", "healthcare", "finance", "retail", "manufacturing",
    "media", "real estate", "education", "energy",
]

NON_TECH_ROLES = [
    "product manager", "marketing manager", "operations lead",
    "business analyst", "sales director",
]

GD_TOPICS = [
    "AI will replace more jobs than it creates",
    "Remote work hurts junior employee growth",
    "India should adopt lighter AI regulation than the EU",
    "Social media does more harm than good",
    "Four-day work weeks improve productivity",
    "Startups should prioritise profitability over growth",
    "Electric vehicles will solve urban pollution",
    "Cryptocurrency will replace traditional banking",
    "Online education is better than classroom learning",
    "Reservations in private sector jobs: pros and cons",
    "Should coding be mandatory in school curriculum",
    "Gig economy: empowerment or exploitation",
]

CLIENT_COMPLAINTS = [
    "product delivery was delayed by 3 weeks causing financial loss",
    "dashboard showed incorrect data during month-end close",
    "customer support response time exceeded the SLA",
    "API integration broke without warning during a peak period",
    "promised feature was cut without prior notice",
]

USER_QUALITY_PROFILES = [
    {
        "label": "excellent",
        "instruction": "The user (candidate) is articulate, gives specific examples, uses data, handles objections well, and speaks confidently.",
    },
    {
        "label": "good",
        "instruction": "The user gives decent answers with some specific examples but occasionally misses depth or trails off slightly.",
    },
    {
        "label": "average",
        "instruction": "The user's answers are acceptable but generic, sometimes lacks examples, uses a few filler words like 'um' or 'basically'.",
    },
    {
        "label": "weak",
        "instruction": "The user is vague, uses many filler words ('um', 'like', 'you know', 'kind of'), lacks specific examples, and hedges excessively.",
    },
    {
        "label": "poor",
        "instruction": "The user gives very short, unclear answers, is defensive or nervous, says 'I don't know' frequently, and does not improve even when probed.",
    },
]

# ── Prompt builder ─────────────────────────────────────────────────────────────

GENERATION_SYSTEM = """You are a dataset generator for CommuniQ, an AI-based conversation simulator that helps students and professionals practice communication skills (HR interviews, technical interviews, group discussions, sales pitches, client handling).

Generate a realistic multi-turn conversation (6-10 turns minimum) where:
- The AI plays the role specified in the system prompt
- The user (candidate) exhibits the quality profile described
- Turns are realistic, varied, and natural — not formulaic
- Each AI turn is at most 2-3 sentences unless the role demands more
- Each user turn is realistic for their quality level

IMPORTANT:
- Return ONLY valid JSON — no explanation, no markdown, no code blocks
- The JSON must be exactly this structure:
{
  "sessionId": "gen_XXX",
  "scenarioType": "<type>",
  "systemPrompt": "<the AI's role instruction>",
  "turns": [
    {"role": "ai", "transcript": "..."},
    {"role": "user", "transcript": "..."}
  ]
}
- Start with an AI turn (the AI opens the conversation)
- Minimum 6 turns (3 AI + 3 user), target 8-10 turns
- Make the conversation feel real — the AI adapts to the user's quality
"""


def build_generation_prompt(scenario_type: str, session_idx: int) -> str:
    templates = SCENARIO_TEMPLATES[scenario_type]
    tmpl = random.choice(templates)
    quality = random.choice(USER_QUALITY_PROFILES)

    system_raw = tmpl["system"]
    system_filled = system_raw.format(
        seniority=random.choice(SENIORITY_LEVELS),
        company_type=random.choice(COMPANY_TYPES),
        personality=random.choice(PERSONALITIES),
        role=random.choice(NON_TECH_ROLES),
        buyer_role=random.choice(BUYER_ROLES),
        industry=random.choice(INDUSTRIES),
        gd_topic=random.choice(GD_TOPICS),
        complaint=random.choice(CLIENT_COMPLAINTS),
    )

    return f"""Generate a training conversation for CommuniQ.

Scenario type: {scenario_type}
Topic: {tmpl['topic']}
Session ID: gen_{session_idx:04d}

AI role (system prompt): {system_filled}

User quality: {quality['label']}
User profile: {quality['instruction']}

Generate the full conversation JSON now."""


# ── API clients ────────────────────────────────────────────────────────────────

def call_groq(client, model: str, prompt: str) -> str:
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": GENERATION_SYSTEM},
            {"role": "user", "content": prompt},
        ],
        temperature=0.9,
        max_tokens=2048,
    )
    return response.choices[0].message.content or ""


def call_openai(client, model: str, prompt: str) -> str:
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": GENERATION_SYSTEM},
            {"role": "user", "content": prompt},
        ],
        temperature=0.9,
        max_tokens=2048,
    )
    return response.choices[0].message.content or ""


def parse_session(raw: str, fallback_idx: int) -> dict | None:
    raw = raw.strip()
    # Strip markdown code fences if present
    if raw.startswith("```"):
        lines = raw.split("\n")
        raw = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        # Try to extract first {...} block
        start = raw.find("{")
        end = raw.rfind("}")
        if start == -1 or end == -1:
            return None
        try:
            obj = json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            return None

    if not isinstance(obj, dict):
        return None
    if "turns" not in obj or not isinstance(obj["turns"], list):
        return None
    if len(obj["turns"]) < 4:
        return None

    obj.setdefault("sessionId", f"gen_{fallback_idx:04d}")
    return obj


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    p = argparse.ArgumentParser(description="Generate bulk CommuniQ training sessions")
    p.add_argument("--count", type=int, default=200, help="Number of sessions to generate")
    p.add_argument(
        "--output",
        type=Path,
        default=Path("training/data/sessions_bulk.json"),
        help="Output JSON file path",
    )
    p.add_argument(
        "--backend",
        choices=["groq", "openai"],
        default="groq",
        help="LLM API backend to use",
    )
    p.add_argument(
        "--model",
        default=None,
        help="Model ID (default: llama-3.3-70b-versatile for groq, gpt-4o-mini for openai)",
    )
    p.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Seconds to wait between API calls (rate-limit safety)",
    )
    p.add_argument(
        "--resume",
        action="store_true",
        help="Resume from existing output file (skip already-generated sessions)",
    )
    args = p.parse_args()

    # ── Init API client ──
    if args.backend == "groq":
        try:
            from groq import Groq  # type: ignore
        except ImportError:
            raise SystemExit("Install groq: pip install groq")
        api_key = os.environ.get("GROQ_API_KEY") or ""
        if not api_key:
            raise SystemExit("Set GROQ_API_KEY environment variable")
        client = Groq(api_key=api_key)
        model = args.model or "llama-3.3-70b-versatile"
        call_fn = lambda prompt, idx: call_groq(client, model, prompt)
    else:
        try:
            from openai import OpenAI  # type: ignore
        except ImportError:
            raise SystemExit("Install openai: pip install openai")
        api_key = os.environ.get("OPENAI_API_KEY") or ""
        if not api_key:
            raise SystemExit("Set OPENAI_API_KEY environment variable")
        client = OpenAI(api_key=api_key)
        model = args.model or "gpt-4o-mini"
        call_fn = lambda prompt, idx: call_openai(client, model, prompt)

    print(f"Backend: {args.backend} / Model: {model}", file=sys.stderr)

    # ── Load existing if resuming ──
    existing: list[dict] = []
    if args.resume and args.output.exists():
        existing = json.loads(args.output.read_text(encoding="utf-8"))
        print(f"Resuming — {len(existing)} sessions already generated", file=sys.stderr)

    sessions = list(existing)
    start_idx = len(existing)
    needed = args.count - start_idx

    if needed <= 0:
        print(f"Already have {len(existing)} sessions. Nothing to generate.", file=sys.stderr)
        return

    print(f"Generating {needed} new sessions (total target: {args.count})", file=sys.stderr)

    # Distribute scenario types evenly
    scenario_pool = (SCENARIO_TYPES * ((needed // len(SCENARIO_TYPES)) + 2))[:needed]
    random.shuffle(scenario_pool)

    failed = 0
    for i, scenario_type in enumerate(scenario_pool, start=start_idx):
        prompt = build_generation_prompt(scenario_type, i)
        print(f"[{i + 1}/{args.count}] {scenario_type}...", end=" ", flush=True, file=sys.stderr)

        try:
            raw = call_fn(prompt, i)
            session = parse_session(raw, i)
            if session is None:
                print("PARSE FAIL — skipped", file=sys.stderr)
                failed += 1
                continue
            sessions.append(session)
            print(f"ok ({len(session['turns'])} turns)", file=sys.stderr)
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            failed += 1
            time.sleep(args.delay * 2)
            continue

        # Save incrementally every 10 sessions
        if (i + 1) % 10 == 0:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(
                json.dumps(sessions, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            print(f"  → Saved {len(sessions)} sessions so far", file=sys.stderr)

        time.sleep(args.delay)

    # Final save
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(sessions, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        f"\nDone. Generated {len(sessions) - len(existing)} new sessions. "
        f"Total: {len(sessions)}. Failed/skipped: {failed}",
        file=sys.stderr,
    )
    print(str(args.output))


if __name__ == "__main__":
    main()
