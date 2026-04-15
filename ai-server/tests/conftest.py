"""
Pytest hooks: default env for tests without Groq keys.

Set COMMUNIQ_TEST_LOCAL=0 to skip these defaults and use your real .env only.
"""

import os


def pytest_configure(config) -> None:  # noqa: ARG001
    if os.environ.get("COMMUNIQ_TEST_LOCAL", "1") == "0":
        return
    os.environ.setdefault("ASR_BACKEND", "local")
    os.environ.setdefault("LLM_BACKEND", "ollama")
    os.environ.setdefault("TTS_BACKEND", "local")
    os.environ.setdefault("EVAL_LLM_BACKEND", "ollama")
