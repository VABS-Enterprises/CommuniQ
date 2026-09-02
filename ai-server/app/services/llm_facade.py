"""
LLM chat completions. Two entry points:

  chat_completion()      — conversation turns (/session/opening, /session/turn)
                           backend selected by LLM_BACKEND env var
  eval_chat_completion() — post-session evaluation (/session/evaluate)
                           backend selected by EVAL_LLM_BACKEND env var

Backend options for both:
  groq          — Groq cloud API (requires GROQ_API_KEY)
  openai_compat — Any OpenAI-compatible HTTPS API (Together, OpenRouter,
                  OpenAI, Fireworks, hosted vLLM with auth). Requires
                  OPENAI_COMPAT_BASE_URL + OPENAI_COMPAT_API_KEY; model id
                  from LLM_MODEL / EVAL_LLM_MODEL.
  ollama        — local Ollama daemon
  vllm          — local vLLM server (Linux + CUDA)
"""

import logging
import re
from typing import Any, Optional

import httpx
from groq import AsyncGroq

from app.config import settings

logger = logging.getLogger("communiq")


# ── Reasoning models ──────────────────────────────────────────────────────────
#
# Some hosted models think before they answer, and that thinking is billed
# against max_tokens. Ask gpt-oss-20b for an 80-token greeting and it spends
# ~78 of them reasoning, then returns finish_reason="length" with content="".
# Every conversation turn in the app failed this way once the models moved to
# the gpt-oss family — the caller saw an empty string and raised a 502.
#
# Two defences, applied here so no call site has to know about any of it:
#   1. Send reasoning_effort so the thinking stays short.
#   2. Floor max_tokens, leaving room for thinking plus the actual reply.

_REASONING_MODEL_MARKERS = ("gpt-oss", "qwen3", "deepseek-r1", "o1", "o3")

# Some models emit their scratchpad inline as <think>...</think> instead of
# putting it in a separate field. It must never reach the user or a JSON parser.
_THINK_BLOCK = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
_UNCLOSED_THINK = re.compile(r"<think>.*$", re.DOTALL | re.IGNORECASE)


def is_reasoning_model(model: str) -> bool:
    """True when `model` spends output tokens thinking before it answers."""
    m = (model or "").lower()
    return any(marker in m for marker in _REASONING_MODEL_MARKERS)


def _budget_for(model: str, max_tokens: int) -> int:
    """Token budget, raised to leave room for a reasoning model's thinking."""
    if is_reasoning_model(model):
        return max(max_tokens, settings.reasoning_token_floor)
    return max_tokens


def content_of(response) -> str:
    """
    The assistant's actual words, with any reasoning stripped out.

    Call sites used to read `response.choices[0].message.content` directly and
    treat an empty string as a hard failure. That is exactly what a reasoning
    model returns when it runs out of budget mid-thought, so the read is
    centralised here: scratchpad tags are removed, and the separate `reasoning`
    field is never substituted for a real answer — an empty result stays empty
    so the caller can still tell that the model produced nothing usable.
    """
    try:
        message = response.choices[0].message
    except (AttributeError, IndexError):
        return ""

    text = getattr(message, "content", None) or ""
    text = _THINK_BLOCK.sub("", text)
    text = _UNCLOSED_THINK.sub("", text)
    return text.strip()


# ── Public API ────────────────────────────────────────────────────────────────

async def chat_completion(
    groq: AsyncGroq,
    *,
    model: str,
    messages: list[dict[str, Any]],
    max_tokens: int,
    temperature: float,
    timeout: float,
):
    """Conversation turn LLM call. Backend: LLM_BACKEND env var."""
    return await _dispatch(
        backend=settings.llm_backend,
        groq=groq,
        model=model,
        messages=messages,
        max_tokens=_budget_for(model, max_tokens),
        temperature=temperature,
        timeout=timeout,
    )


async def eval_chat_completion(
    groq: Optional[AsyncGroq],
    *,
    messages: list[dict[str, Any]],
    max_tokens: int,
    temperature: float,
    timeout: float,
):
    """
    Evaluation LLM call. Backend: EVAL_LLM_BACKEND env var.

    Uses its own model setting (EVAL_LLM_MODEL) so evaluation can stay on
    a stronger model (e.g. groq 8B) while conversation runs on a local 3B.
    """
    return await _dispatch(
        backend=settings.eval_llm_backend,
        groq=groq,
        model=settings.eval_llm_model,
        messages=messages,
        max_tokens=_budget_for(settings.eval_llm_model, max_tokens),
        temperature=temperature,
        timeout=timeout,
    )


# ── Internal dispatcher ───────────────────────────────────────────────────────

async def _dispatch(
    backend: str,
    groq: Optional[AsyncGroq],
    model: str,
    messages: list[dict[str, Any]],
    max_tokens: int,
    temperature: float,
    timeout: float,
):
    if backend == "groq":
        if groq is None:
            raise RuntimeError(
                "LLM path uses Groq but the Groq client was not initialised. "
                "Set GROQ_API_KEY or switch LLM_BACKEND / EVAL_LLM_BACKEND to ollama/vllm."
            )
        kwargs: dict[str, Any] = {}
        if is_reasoning_model(model):
            # Keeps the scratchpad to ~10-15 tokens instead of consuming the
            # whole budget. Unsupported values are rejected by the API, so the
            # setting is validated at startup rather than here.
            kwargs["reasoning_effort"] = settings.llm_reasoning_effort

        response = await groq.chat.completions.create(
            model=model,
            messages=messages,
            stream=False,
            max_tokens=max_tokens,
            temperature=temperature,
            timeout=timeout,
            **kwargs,
        )

        if not content_of(response):
            # Worth a loud log: an empty reply is almost always the reasoning
            # budget running out, and the fix is a config change rather than a
            # retry.
            finish = getattr(response.choices[0], "finish_reason", "?")
            logger.error(
                "LLM returned no content — model=%s finish=%s max_tokens=%d "
                "effort=%s. If finish=length, raise REASONING_TOKEN_FLOOR or "
                "lower LLM_REASONING_EFFORT.",
                model, finish, max_tokens, kwargs.get("reasoning_effort", "n/a"),
            )
        return response

    if backend == "ollama":
        return await _openai_compat_chat(
            base_url=settings.ollama_base_url,
            model=settings.ollama_model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            timeout=timeout,
            server_name="Ollama",
            start_hint="ollama serve",
            api_key=None,
        )

    if backend == "vllm":
        return await _openai_compat_chat(
            base_url=settings.vllm_base_url,
            model=settings.vllm_model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            timeout=timeout,
            server_name="vLLM",
            start_hint=(
                "python -m vllm.entrypoints.openai.api_server "
                f"--model {settings.vllm_model} --port 8001"
            ),
            api_key=None,
        )

    if backend == "openai_compat":
        return await _openai_compat_chat(
            base_url=settings.openai_compat_base_url,
            model=model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            timeout=timeout,
            server_name="OpenAI-compatible API",
            start_hint=(
                "Set OPENAI_COMPAT_BASE_URL and OPENAI_COMPAT_API_KEY "
                "(e.g. Together, OpenRouter, or your hosted inference URL)."
            ),
            api_key=settings.openai_compat_api_key,
        )

    raise ValueError(
        f"Unknown LLM backend: {backend!r}. "
        "Set LLM_BACKEND or EVAL_LLM_BACKEND to one of: "
        "groq, openai_compat, ollama, vllm"
    )


# ── OpenAI-compatible HTTP helper (Ollama, vLLM, cloud APIs) ────────────────


def _chat_completions_url(base_url: str) -> str:
    """
    Build POST URL for OpenAI-compatible chat completions.

    Accepts either:
      - https://api.openai.com  -> .../v1/chat/completions
      - https://api.together.xyz/v1  -> .../v1/chat/completions (no double /v1)
    """
    b = base_url.rstrip("/")
    if b.endswith("/v1"):
        return f"{b}/chat/completions"
    return f"{b}/v1/chat/completions"


async def _openai_compat_chat(
    *,
    base_url: str,
    model: str,
    messages: list[dict[str, Any]],
    max_tokens: int,
    temperature: float,
    timeout: float,
    server_name: str,
    start_hint: str,
    api_key: str | None = None,
) -> "_LocalLLMResponse":
    """
    POST chat/completions in OpenAI format. Local servers omit api_key;
    cloud providers use Bearer auth.
    """
    url = _chat_completions_url(base_url)
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "stream": False,
    }
    headers: dict[str, str] = {}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            resp = await client.post(url, json=payload, headers=headers)
            resp.raise_for_status()
        except httpx.ConnectError as exc:
            raise RuntimeError(
                f"Cannot reach {server_name} at {base_url}. "
                f"Make sure it is running: {start_hint}"
            ) from exc
        except httpx.HTTPStatusError as exc:
            raise RuntimeError(
                f"{server_name} returned HTTP {exc.response.status_code}: "
                f"{exc.response.text[:300]}"
            ) from exc

    data = resp.json()
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as exc:
        raise RuntimeError(
            f"{server_name} response missing expected fields: {data}"
        ) from exc

    logger.info(
        "Local LLM (%s): model=%s, finish=%s, tokens=%s",
        server_name,
        model,
        data.get("choices", [{}])[0].get("finish_reason", "?"),
        data.get("usage", {}).get("completion_tokens", "?"),
    )
    return _LocalLLMResponse(content)


# ── Response wrapper ──────────────────────────────────────────────────────────

class _LocalLLMResponse:
    """
    Mimics the Groq SDK response shape (.choices[0].message.content) so that
    every caller in session.py works unchanged regardless of backend.
    """

    class _Message:
        def __init__(self, content: str) -> None:
            self.content = content

    class _Choice:
        def __init__(self, content: str) -> None:
            self.message = _LocalLLMResponse._Message(content)

    def __init__(self, content: str) -> None:
        self.choices = [self._Choice(content)]
