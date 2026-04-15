# CP3: CUDA driver, GPU memory, Pipecat /health (versions + VRAM), Ollama tags.
# Run from repo root with Pipecat on :9000 and Ollama on :11434.
# Usage: powershell -File scripts/verify-cp3.ps1

$ErrorActionPreference = "Continue"

Write-Host "`n=== nvidia-smi (driver + CUDA + memory) ===" -ForegroundColor Cyan
try {
    & nvidia-smi 2>&1
} catch {
    Write-Host "nvidia-smi not found or failed: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Pipecat /health (incl. cp3_stack) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:9000/health" -UseBasicParsing -TimeoutSec 8
    $j = $r.Content | ConvertFrom-Json
    Write-Host ($j | ConvertTo-Json -Depth 8)
} catch {
    Write-Host "FAIL (start worker: uvicorn main:app --port 9000 in pipecat-worker) $_" -ForegroundColor Red
}

Write-Host "`n=== Ollama models (11434) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 8
    Write-Host $r.Content
} catch {
    Write-Host "FAIL $_" -ForegroundColor Yellow
}

Write-Host "`nCP3 checks: faster_whisper + ctranslate2 versions should match a CUDA wheel" -ForegroundColor Green
Write-Host "supported by your driver (see cp3_stack.nvidia_smi_cuda_version). PyTorch is optional" -ForegroundColor Green
Write-Host "in this worker; if you install torch for other tools, torch_cuda_version should align.`n" -ForegroundColor Green
