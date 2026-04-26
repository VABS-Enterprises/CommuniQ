from fastapi import APIRouter

from app.api.v1 import evaluate, session, transcribe, tts

router = APIRouter()

# Endpoints are mounted at root level (no /api/v1 prefix) for Node backend compatibility.
#
# Canonical evaluation surface (new):
#   POST /evaluate/roleplay   — replaces /session/evaluate
#   POST /evaluate/learning   — learning module answer evaluation
#   POST /evaluate/contest    — debate/GD/extempore evaluation
#
# HTTP fallback + legacy (maintenance-only, no new features):
#   POST /session/opening
#   POST /session/turn
#   POST /session/evaluate    — deprecated alias for /evaluate/roleplay
#
# Other:
#   POST /tts
#   GET  /health
router.include_router(evaluate.router)
router.include_router(session.router)
router.include_router(tts.router)
router.include_router(transcribe.router)
