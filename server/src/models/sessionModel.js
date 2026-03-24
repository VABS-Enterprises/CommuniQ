const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — sessions/{sessionId}
 * ───────────────────────────────────────
 * sessionId        string
 * userId           string    ref → users/{uid}
 * scenarioId       string    ref → scenarios/{scenarioId}
 * startedAt        timestamp
 * endedAt          timestamp   null until session ends
 * durationSeconds  number      null until session ends
 * status           string    "in_progress" | "completed" | "abandoned"
 * turns            Turn[]
 *
 * Turn shape:
 *   role        string   "user" | "ai"
 *   transcript  string
 *   timestamp   string   ISO 8601
 */

function createSessionDoc(sessionId, { userId, scenarioId, scenarioTitle, persona, tone, languageLevel }) {
  return {
    sessionId,
    userId,
    scenarioId,
    scenarioTitle: scenarioTitle || null,
    persona: persona || null,
    tone: tone || null,
    languageLevel: languageLevel || null,
    overallScore: null,
    startedAt: FieldValue.serverTimestamp(),
    endedAt: null,
    durationSeconds: null,
    status: 'in_progress',
    turns: [],
  };
}

function createTurnDoc(role, transcript) {
  return {
    role,
    transcript,
    timestamp: new Date().toISOString(),
  };
}

module.exports = { createSessionDoc, createTurnDoc };
