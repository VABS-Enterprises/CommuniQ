# CP2: Automated smoke checks before manual phone E2E (LiveKit + Node + Pipecat + Ollama).
# Manual: start a live session on device, speak, confirm AI audio; interrupt mid-reply (barge-in).
#
# Usage: powershell -File scripts/e2e-live-voice-check.ps1

$ErrorActionPreference = "Continue"

Write-Host "`n=== LiveKit ===" -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:7880" -UseBasicParsing -TimeoutSec 3 | Out-Null
    Write-Host "OK :7880 reachable"
} catch { Write-Host "FAIL LiveKit" -ForegroundColor Red }

Write-Host "`n=== Node ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:3000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "OK" $r.StatusCode
} catch { Write-Host "FAIL Node :3000" -ForegroundColor Yellow }

Write-Host "`n=== Pipecat worker ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:9000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host $r.Content
} catch { Write-Host "FAIL Pipecat :9000" -ForegroundColor Red }

Write-Host "`n=== Ollama ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 5
    Write-Host "OK /api/tags"
} catch { Write-Host "FAIL Ollama" -ForegroundColor Yellow }

Write-Host "`nManual CP2: Flutter live voice session -> verify reply audio + barge-in." -ForegroundColor Green
Write-Host "Worker logs: Local ASR wall_ms=..., Kokoro wall_ms=...`n" -ForegroundColor Green
