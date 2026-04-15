# CP1: Quick checks for ai-server local pipeline (HTTP path).
# Prerequisites: ai-server venv, Ollama running if using ollama backend, ffmpeg for local TTS.
#
# Matrix (set in ai-server/.env then restart uvicorn):
#   ASR only   — ASR_BACKEND=local,  LLM_BACKEND=groq,   TTS_BACKEND=edge   (+ GROQ_API_KEY)
#   TTS only   — ASR_BACKEND=groq,   LLM_BACKEND=groq,   TTS_BACKEND=local  (+ GROQ)
#   LLM only   — ASR_BACKEND=groq,   LLM_BACKEND=ollama,TTS_BACKEND=edge
#   Full local — ASR_BACKEND=local,  LLM_BACKEND=ollama,TTS_BACKEND=local
#
# Usage:
#   cd ai-server; uvicorn app.main:app --port 8000
#   powershell -File scripts/verify-cp1-facades.ps1

$base = "http://127.0.0.1:8000"
Write-Host "`n=== GET $base/health ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "$base/health" -UseBasicParsing -TimeoutSec 10
    Write-Host $r.Content
} catch {
    Write-Host "FAIL — start ai-server: cd ai-server; uvicorn app.main:app --port 8000" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== POST $base/tts (smoke) ===" -ForegroundColor Cyan
try {
    $body = '{"text":"CP1 TTS smoke test."}'
    $r = Invoke-WebRequest -Uri "$base/tts" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 120
    Write-Host "OK audio/mpeg bytes:" $r.RawContentLength
} catch {
    Write-Host "FAIL $_" -ForegroundColor Red
}

Write-Host "`nCP1 full pipeline test: python -m tests.test_pipeline (from ai-server/, server running)" -ForegroundColor Green
Write-Host "Automated contract:     python -m pytest tests/test_health_contract.py -q`n" -ForegroundColor Green
