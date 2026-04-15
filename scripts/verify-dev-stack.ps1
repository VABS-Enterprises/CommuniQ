# Quick CP2/CP3 dev checks — run while LiveKit, Node, Pipecat, Ollama are up.
# Usage: powershell -File scripts/verify-dev-stack.ps1

$ErrorActionPreference = "Continue"
Write-Host "`n=== LiveKit (7880) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:7880" -UseBasicParsing -TimeoutSec 3
    Write-Host "OK $($r.StatusCode) $($r.Content)"
} catch {
    Write-Host "FAIL $_" -ForegroundColor Red
}

Write-Host "`n=== Node (3000 /health) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:3000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "OK $($r.StatusCode)"
} catch {
    Write-Host "FAIL (is Node on PORT 3000?) $_" -ForegroundColor Yellow
}

Write-Host "`n=== Pipecat worker (9000 /health) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:9000/health" -UseBasicParsing -TimeoutSec 5
    Write-Host $r.Content
} catch {
    Write-Host "FAIL $_" -ForegroundColor Red
}

Write-Host "`n=== Ollama (11434 /api/tags) ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 5
    Write-Host "OK models endpoint reachable"
} catch {
    Write-Host "FAIL $_" -ForegroundColor Yellow
}

Write-Host "`nDone.`n" -ForegroundColor Green
