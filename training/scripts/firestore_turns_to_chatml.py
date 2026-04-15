#!/usr/bin/env python3
"""
Convert exported CommuniQ session JSON into ChatML-style JSONL for CP4.

Input JSON: either
  - a list of session objects, or
  - {"sessions": [ ... ]}

Each session object may contain:
  - system_prompt | systemPrompt | scenarioSystemPrompt
  - turns: [{ "role": "user"|"ai"|"assistant", "transcript"|"content": "..." }, ...]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def _normalize_role(r: str) -> str:
    r = (r or "").strip().lower()
    if r in ("ai", "assistant"):
        return "assistant"
    if r == "user":
        return "user"
    return "user"


def _turn_to_message(t: dict[str, Any]) -> dict[str, str] | None:
    role = _normalize_role(str(t.get("role", "user")))
    text = (t.get("transcript") or t.get("content") or "").strip()
    if not text:
        return None
    return {"role": role, "content": text}


def session_to_record(doc: dict[str, Any]) -> dict[str, Any] | None:
    system = (
        doc.get("system_prompt")
        or doc.get("systemPrompt")
        or doc.get("scenarioSystemPrompt")
        or ""
    ).strip()
    turns = doc.get("turns") or doc.get("conversation") or []
    if not isinstance(turns, list):
        return None
    messages: list[dict[str, str]] = []
    if system:
        messages.append({"role": "system", "content": system})
    for t in turns:
        if not isinstance(t, dict):
            continue
        m = _turn_to_message(t)
        if m:
            messages.append(m)
    if len(messages) < 2:
        return None
    return {"messages": messages}


def load_sessions(path: Path) -> list[dict[str, Any]]:
    raw = json.loads(path.read_text(encoding="utf-8-sig"))
    if isinstance(raw, list):
        return [x for x in raw if isinstance(x, dict)]
    if isinstance(raw, dict) and isinstance(raw.get("sessions"), list):
        return [x for x in raw["sessions"] if isinstance(x, dict)]
    raise SystemExit("Input must be a JSON list of sessions or {sessions: [...]}")


def main() -> None:
    p = argparse.ArgumentParser(description="Firestore-style export -> ChatML JSONL")
    p.add_argument("--input", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    args = p.parse_args()

    sessions = load_sessions(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with args.output.open("w", encoding="utf-8") as out:
        for doc in sessions:
            rec = session_to_record(doc)
            if rec:
                out.write(json.dumps(rec, ensure_ascii=False) + "\n")
                n += 1
    print(f"Wrote {n} conversations to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
