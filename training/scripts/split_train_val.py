#!/usr/bin/env python3
"""Shuffle and split JSONL into train / validation files."""

from __future__ import annotations

import argparse
import random
from pathlib import Path


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--input", type=Path, required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--val-ratio", type=float, default=0.1)
    p.add_argument("--seed", type=int, default=42)
    args = p.parse_args()

    lines = [ln for ln in args.input.read_text(encoding="utf-8").splitlines() if ln.strip()]
    rng = random.Random(args.seed)
    rng.shuffle(lines)
    if len(lines) <= 1:
        n_val = 0
    else:
        n_val = max(1, int(len(lines) * args.val_ratio))
    val_lines = lines[:n_val]
    train_lines = lines[n_val:] if n_val else lines

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "train.jsonl").write_text("\n".join(train_lines) + ("\n" if train_lines else ""), encoding="utf-8")
    (args.out_dir / "val.jsonl").write_text("\n".join(val_lines) + ("\n" if val_lines else ""), encoding="utf-8")
    print(f"train={len(train_lines)} val={len(val_lines)} -> {args.out_dir}")


if __name__ == "__main__":
    main()
