from fastapi import APIRouter

from app.api.v1 import session, tts

router = APIRouter()

# Endpoints are mounted at root level (no /api/v1 prefix) for Node backend compatibility:
#   POST /session/turn
#   POST /session/evaluate
#   POST /tts
#   GET  /health
router.include_router(session.router)
router.include_router(tts.router)
