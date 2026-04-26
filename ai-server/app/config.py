import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    groq_api_key: str = os.getenv("GROQ_API_KEY", "")
    port: int = int(os.getenv("PORT", "8000"))
    llm_model: str = os.getenv("LLM_MODEL", "llama-3.1-8b-instant")

    # ── Internal security ─────────────────────────────────────────────────────
    # Shared secret between Node backend and ai-server.
    # When set, ALL non-health endpoints require the header:
    #   X-Ai-Server-Key: <value>
    # Must match AI_SERVER_INTERNAL_KEY in server/.env.
    # If empty, auth is skipped with a startup warning (dev/local only).
    internal_api_key: str = os.getenv("AI_SERVER_INTERNAL_KEY", "").strip()

    # Comma-separated list of allowed CORS origins.
    # In production set to the Node backend's public URL, e.g.:
    #   ALLOWED_ORIGINS=https://communiq-backend.onrender.com
    # Defaults to "*" only when the env var is absent (dev/local).
    allowed_origins_raw: str = os.getenv("ALLOWED_ORIGINS", "*").strip()

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

    # ── Evaluation backend ────────────────────────────────────────────────────
    # Used exclusively by /session/evaluate.
    # Defaults to groq because evaluation needs stronger reasoning than
    # conversation turns — keep this on 8B even when turns use a local 3B model.
    eval_llm_backend: str = os.getenv("EVAL_LLM_BACKEND", "groq").strip().lower()
    eval_llm_model: str = os.getenv("EVAL_LLM_MODEL", "llama-3.1-8b-instant")

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
    def allowed_origins(self) -> list[str]:
        """Parsed list of allowed CORS origins. ['*'] when wildcard."""
        raw = self.allowed_origins_raw
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]

    def validate(self) -> None:
        import logging as _logging
        _log = _logging.getLogger("communiq.config")

        if not self.internal_api_key:
            _log.warning(
                "AI_SERVER_INTERNAL_KEY is not set. "
                "The ai-server will accept requests from ANY caller. "
                "Set AI_SERVER_INTERNAL_KEY in ai-server/.env for production."
            )

        if self.allowed_origins == ["*"]:
            _log.warning(
                "ALLOWED_ORIGINS is '*' — ai-server accepts requests from any origin. "
                "Set ALLOWED_ORIGINS to the Node backend URL in production."
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

        valid_tts = {"groq", "edge", "local"}
        if self.tts_backend not in valid_tts:
            raise RuntimeError(
                f"TTS_BACKEND={self.tts_backend!r} is not recognised. "
                f"Choose one of: {', '.join(sorted(valid_tts))}"
            )


settings = Settings()
