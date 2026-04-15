#!/usr/bin/env python3
"""
Lightweight PII scrubbing for JSONL lines with a top-level \"messages\" array.

Reads stdin, writes stdout. Each line must be a JSON object.
Extend PATTERNS for your locale (PAN, Aadhaar patterns, etc.).
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any

# Email, phone-ish digit runs, credit-card-like groups (conservative)
PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "<email>"),
    (re.compile(r"\b\+?\d[\d\s\-().]{8,}\b"), "<phone>"),
    (re.compile(r"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"), "<card>"),
]


def scrub_text(s: str) -> str:
    out = s
    for pat, rep in PATTERNS:
        out = pat.sub(rep, out)
    return out


def scrub_messages(obj: dict[str, Any]) -> dict[str, Any]:
    msgs = obj.get("messages")
    if not isinstance(msgs, list):
        return obj
    new_msgs = []
    for m in msgs:
        if isinstance(m, dict) and "content" in m:
            c = m.get("content")
            if isinstance(c, str):
                m = {**m, "content": scrub_text(c)}
        new_msgs.append(m)
    return {**obj, "messages": new_msgs}


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        if isinstance(obj, dict):
            obj = scrub_messages(obj)
        print(json.dumps(obj, ensure_ascii=False))


if __name__ == "__main__":
    main()
