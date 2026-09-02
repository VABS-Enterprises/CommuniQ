import os
from pathlib import Path

from dotenv import load_dotenv

# Anchor the .env lookup to the ai-server directory rather than the process's
# working directory. Bare load_dotenv() searches upward from CWD, so starting
# uvicorn from the repo root silently found no file and every key came back
# empty — the app then failed much later with a confusing "GROQ_API_KEY is not
# set", even though the key was sitting in ai-server/.env the whole time.
_ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=_ENV_PATH)


class Settings:
    groq_api_key: str = os.getenv("GROQ_API_KEY", "")
    port: int = int(os.getenv("PORT", "8000"))
    # Groq retired the llama-3.1-* models; requests for them now fail with
    # model_not_found, which took down every evaluation path in the app.
    # openai/gpt-oss-20b is the current Groq-hosted equivalent and returns
    # the strict JSON these evaluators parse.
    llm_model: str = os.getenv("LLM_MODEL", "openai/gpt-oss-20b")

    # ── Environment ────────────────────────────────────────────────────────────
    # "development" (default) | "production"
    # Controls whether missing security config (internal API key, CORS origins)
    # is a startup warning (dev) or a hard startup failure (production).
    environment: str = os.getenv("ENVIRONMENT", "development").strip().lower()

    # ── Internal security ─────────────────────────────────────────────────────
    # Shared secret between Node backend and ai-server.
    # When set, ALL non-health endpoints require the header:
    #   X-Ai-Server-Key: <value>
    # Must match AI_SERVER_INTERNAL_KEY in server/.env.
    # If empty, auth is skipped with a startup warning in development.
    # In production (ENVIRONMENT=production), an empty key fails startup — see validate().
    internal_api_key: str = os.getenv("AI_SERVER_INTERNAL_KEY", "").strip()

    # Comma-separated list of allowed CORS origins.
    # In production set to the Node backend's public URL, e.g.:
    #   ALLOWED_ORIGINS=https://communiq-backend.onrender.com
    # Defaults to "" (no origins allowed) when the env var is absent — this is an
    # internal service called only by the Node backend, not a public API, so it
    # must not default open. "*" is still accepted if explicitly set, but is
    # rejected at startup in production — see validate().
    allowed_origins_raw: str = os.getenv("ALLOWED_ORIGINS", "").strip()

    # ── Conversation pipeline backends ────────────────────────────────────────
    # Used by /session/opening and /session/turn.
    #
    # groq          — Groq cloud API (requires GROQ_API_KEY)
    # openai_compat — any OpenAI-compatible HTTPS API (see OPENAI_COMPAT_*)
    # ollama        — local Ollama daemon
    # vllm          — local vLLM server (Linux + CUDA)
    asr_backend: str = os.getenv("ASR_BACKEND", "groq").strip().lower()
    llm_backend: str = os.getenv("LLM_BACKEND", "groq").strip().lower()
    tts_backend: str = os.getenv("TTS_BACKEND", "edge").strip().lower()

    # ── Reasoning models ──────────────────────────────────────────────────────
    # Groq's gpt-oss family are *reasoning* models: they spend tokens thinking
    # before they answer, and that thinking is billed against max_tokens. With
    # a small budget the whole allowance goes on reasoning and the reply comes
    # back EMPTY with finish_reason="length" — which took down every
    # conversation turn in the app (opening asked for 80 tokens; 78 of them
    # went to reasoning).
    #
    # "low" keeps the thinking to ~10-15 tokens, which is what short
    # conversational replies need. Raise to "medium"/"high" for harder
    # evaluation work if answers get shallow.
    llm_reasoning_effort: str = os.getenv("LLM_REASONING_EFFORT", "low").strip().lower()

    # Floor applied to any reasoning-model request, so a caller asking for a
    # short reply still leaves room for the thinking that precedes it.
    reasoning_token_floor: int = int(os.getenv("REASONING_TOKEN_FLOOR", "512"))

    # ── Evaluation backend ────────────────────────────────────────────────────
    # Used exclusively by /session/evaluate.
    # Defaults to groq because evaluation needs stronger reasoning than
    # conversation turns — keep this on 8B even when turns use a local 3B model.
    eval_llm_backend: str = os.getenv("EVAL_LLM_BACKEND", "groq").strip().lower()
    eval_llm_model: str = os.getenv("EVAL_LLM_MODEL", "openai/gpt-oss-20b")

    # ── Local STT (ASR_BACKEND=local) ─────────────────────────────────────────
    # Whisper model size: "tiny" | "base" | "small" | "medium" | "large-v3"
    # RTX 2050 (4 GB):  "small" (int8, ~500 MB VRAM) or "medium" (~1.5 GB)
    # College GPU (8 GB+): "large-v3"
    whisper_model: str = os.getenv("WHISPER_MODEL", "small")
    whisper_device: str = os.getenv("WHISPER_DEVICE", "cuda")
    whisper_compute_type: str = os.getenv("WHISPER_COMPUTE_TYPE", "int8")

    # ── Local LLM — Ollama (LLM_BACKEND=ollama) ───────────────────────────────
    # Start Ollama: `ollama serve`
    # Pull model:   `ollama pull llama3.2:3b`
    # Ollama exposes an OpenAI-compatible API at /v1/chat/completions.
    ollama_base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_model: str = os.getenv("OLLAMA_MODEL", "llama3.2:3b")

    # ── Local LLM — vLLM (LLM_BACKEND=vllm) ──────────────────────────────────
    # Requires Linux + CUDA. Start vLLM:
    #   python -m vllm.entrypoints.openai.api_server \
    #          --model meta-llama/Llama-3.1-8B-Instruct \
    #          --port 8001
    # vLLM also exposes /v1/chat/completions — same format as Ollama.
    vllm_base_url: str = os.getenv("VLLM_BASE_URL", "http://localhost:8001")
    vllm_model: str = os.getenv("VLLM_MODEL", "meta-llama/Llama-3.1-8B-Instruct")

    # ── Cloud LLM — OpenAI-compatible (LLM_BACKEND or EVAL_LLM_BACKEND=openai_compat)
    # Base URL examples:
    #   https://api.openai.com
    #   https://api.together.xyz/v1
    #   https://openrouter.ai/api/v1
    # Model id is LLM_MODEL / EVAL_LLM_MODEL (provider-specific string).
    openai_compat_base_url: str = os.getenv("OPENAI_COMPAT_BASE_URL", "").strip().rstrip("/")
    openai_compat_api_key: str = os.getenv("OPENAI_COMPAT_API_KEY", "")

    # ── Local TTS (TTS_BACKEND=local) ─────────────────────────────────────────
    # Kokoro voice ID: af_heart | af_bella | am_adam | bf_emma | bm_george
    kokoro_voice: str = os.getenv("KOKORO_VOICE", "af_heart")

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def allowed_origins(self) -> list[str]:
        """Parsed list of allowed CORS origins. ['*'] when wildcard, [] when unset."""
        raw = self.allowed_origins_raw
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]

    def validate(self) -> None:
        import logging as _logging
        _log = _logging.getLogger("communiq.config")

        if not self.internal_api_key:
            if self.is_production:
                raise RuntimeError(
                    "AI_SERVER_INTERNAL_KEY is not set while ENVIRONMENT=production. "
                    "Refusing to start: the ai-server would accept requests from ANY "
                    "caller. Set AI_SERVER_INTERNAL_KEY in ai-server/.env (it must "
                    "match AI_SERVER_INTERNAL_KEY in server/.env)."
                )
            _log.warning(
                "AI_SERVER_INTERNAL_KEY is not set. "
                "The ai-server will accept requests from ANY caller. "
                "Set AI_SERVER_INTERNAL_KEY in ai-server/.env for production."
            )

        if self.allowed_origins_raw == "" or self.allowed_origins == ["*"]:
            if self.is_production:
                raise RuntimeError(
                    "ALLOWED_ORIGINS is unset or '*' while ENVIRONMENT=production. "
                    "Refusing to start: set ALLOWED_ORIGINS to the Node backend's "
                    "actual origin (e.g. https://communiq-backend.onrender.com) in "
                    "ai-server/.env."
                )
            if self.allowed_origins == ["*"]:
                _log.warning(
                    "ALLOWED_ORIGINS is '*' — ai-server accepts requests from any origin. "
                    "Set ALLOWED_ORIGINS to the Node backend URL in production."
                )
            else:
                _log.warning(
                    "ALLOWED_ORIGINS is not set — ai-server will accept no cross-origin "
                    "browser requests. Set ALLOWED_ORIGINS to the Node backend URL if "
                    "browser-based CORS access is needed."
                )

        groq_backends = {self.asr_backend, self.llm_backend, self.eval_llm_backend}
        if "groq" in groq_backends and not self.groq_api_key:
            raise RuntimeError(
                "GROQ_API_KEY is not set but one or more backends require it "
                f"(ASR_BACKEND={self.asr_backend}, LLM_BACKEND={self.llm_backend}, "
                f"EVAL_LLM_BACKEND={self.eval_llm_backend}). "
                "Add GROQ_API_KEY to ai-server/.env or switch backends."
            )

        openai_llm_backends = {self.llm_backend, self.eval_llm_backend}
        if "openai_compat" in openai_llm_backends:
            if not self.openai_compat_base_url or not self.openai_compat_api_key:
                raise RuntimeError(
                    "LLM_BACKEND or EVAL_LLM_BACKEND is openai_compat but "
                    "OPENAI_COMPAT_BASE_URL or OPENAI_COMPAT_API_KEY is empty. "
                    "Set both in ai-server/.env."
                )

        valid_llm = {"groq", "openai_compat", "ollama", "vllm"}
        for name, value in [
            ("LLM_BACKEND", self.llm_backend),
            ("EVAL_LLM_BACKEND", self.eval_llm_backend),
        ]:
            if value not in valid_llm:
                raise RuntimeError(
                    f"{name}={value!r} is not a recognised backend. "
                    f"Choose one of: {', '.join(sorted(valid_llm))}"
                )

        valid_asr = {"groq", "local"}
        if self.asr_backend not in valid_asr:
            raise RuntimeError(
                f"ASR_BACKEND={self.asr_backend!r} is not recognised. "
                f"Choose one of: {', '.join(sorted(valid_asr))}"
            )

        valid_effort = {"low", "medium", "high"}
        if self.llm_reasoning_effort not in valid_effort:
            raise RuntimeError(
                f"LLM_REASONING_EFFORT={self.llm_reasoning_effort!r} is not recognised. "
                f"Choose one of: {', '.join(sorted(valid_effort))}"
            )

        valid_tts = {"groq", "edge", "local"}
        if self.tts_backend not in valid_tts:
            raise RuntimeError(
                f"TTS_BACKEND={self.tts_backend!r} is not recognised. "
                f"Choose one of: {', '.join(sorted(valid_tts))}"
            )


settings = Settings()
