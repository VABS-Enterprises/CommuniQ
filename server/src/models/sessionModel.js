const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — sessions/{sessionId}
 * ───────────────────────────────────────
 * sessionId          string
 * userId             string    ref → users/{uid}
 * scenarioId         string    ref → scenarios/{scenarioId}  (null for custom sessions)
 * customSystemPrompt string    used when no scenarioId is provided
 * scenarioTitle      string
 * persona            string    AI persona chosen by user
 * tone               string    conversation tone
 * languageLevel      string    difficulty level
 * role               string    user's role in the conversation
 * traits             string    AI personality trait
 * backstory          string    optional extra context
 * startedAt          timestamp
 * endedAt            timestamp   null until session ends
 * durationSeconds    number      null until session ends
 * status             string    "in_progress" | "completed" | "abandoned"
 * turns              Turn[]
 *
 * Turn shape:
 *   role        string   "user" | "ai"
 *   transcript  string
 *   timestamp   string   ISO 8601
 */

function createSessionDoc(sessionId, {
  userId,
  scenarioId,
  scenarioTitle,
  persona,
  tone,
  languageLevel,
  customSystemPrompt,
  role,
  traits,
  backstory,
}) {
  return {
    sessionId,
    userId,
    scenarioId: scenarioId || null,
    scenarioTitle: scenarioTitle || null,
    persona: persona || null,
    tone: tone || null,
    languageLevel: languageLevel || null,
    customSystemPrompt: customSystemPrompt || null,
    role: role || null,
    traits: traits || null,
    backstory: backstory || null,
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
