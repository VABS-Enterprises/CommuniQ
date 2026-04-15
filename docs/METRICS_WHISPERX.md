# Phase 6 — Richer coaching metrics (optional)

Future enhancement: **word- or phoneme-level alignment** (e.g. WhisperX-style forced alignment) on user audio to support:

- Timing feedback (pace, pause length)
- Pronunciation coaching grounded in segments rather than transcript-only inference

This is **not** required for Colab parity or the current evaluator. When adding it:

1. Keep alignment as an optional post-step on recorded audio (or on STT output + audio).
2. Do not block `/session/turn` latency until profiling on target hardware.
3. Extend evaluation or a separate “deep dive” endpoint so the mobile client can opt in.
