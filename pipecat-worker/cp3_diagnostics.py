"""
CP3: one place to report versions for CUDA / CTranslate2 / optional PyTorch.

Lives at package root (not under services/) so GET /health does not import the
full services package and pull Pipecat on startup.
"""

from __future__ import annotations

import importlib.metadata
import subprocess
from typing import Any


def _dist_version(dist_name: str) -> str | None:
    try:
        return importlib.metadata.version(dist_name)
    except importlib.metadata.PackageNotFoundError:
        return None


def _nvidia_driver_cuda() -> str | None:
    """Driver version from nvidia-smi (first GPU)."""
    try:
        proc = subprocess.run(
            ["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            return None
        return proc.stdout.strip().splitlines()[0].strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


def _nvidia_cuda_version_from_smi() -> str | None:
    """CUDA version line from full nvidia-smi header, e.g. '12.7'."""
    try:
        proc = subprocess.run(
            ["nvidia-smi"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode != 0 or not proc.stdout:
            return None
        for line in proc.stdout.splitlines():
            if "CUDA Version:" in line:
                part = line.split("CUDA Version:", 1)[1].strip().split()[0]
                return part
        return None
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return None


def _torch_cuda_block() -> dict[str, Any]:
    out: dict[str, Any] = {
        "torch_installed": False,
        "torch_version": None,
        "torch_cuda_available": None,
        "torch_cuda_version": None,
    }
    try:
        import torch  # noqa: PLC0415

        out["torch_installed"] = True
        out["torch_version"] = getattr(torch, "__version__", None)
        out["torch_cuda_available"] = bool(torch.cuda.is_available())
        out["torch_cuda_version"] = (
            torch.version.cuda if torch.cuda.is_available() else None
        )
    except Exception:  # noqa: BLE001
        pass
    return out


def get_cp3_stack_info() -> dict[str, Any]:
    """
    Safe to call at runtime: no heavy imports except optional torch.
    """
    info: dict[str, Any] = {
        "faster_whisper_version": _dist_version("faster-whisper"),
        "ctranslate2_version": _dist_version("ctranslate2"),
        "nvidia_smi_driver": _nvidia_driver_cuda(),
        "nvidia_smi_cuda_version": _nvidia_cuda_version_from_smi(),
    }
    info.update(_torch_cuda_block())
    info["kokoro_version"] = _dist_version("kokoro")
    return info
