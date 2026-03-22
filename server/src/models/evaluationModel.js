const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — evaluationReports/{sessionId}
 * ─────────────────────────────────────────────────
 * sessionId                  string
 * userId                     string    ref → users/{uid}
 * generatedAt                timestamp
 * scores                     Scores
 * fillerWordCount            number
 * fillerWords                string[]  e.g. ["um", "uh", "basically"]
 * strengths                  string[]  exactly 2 items
 * improvements               string[]  exactly 2 items
 * recommendedNextScenarioId  string
 * rawTranscript              string    full conversation as plain text
 *
 * Scores shape:
 *   clarity     number  0–100
 *   fluency     number  0–100
 *   confidence  number  0–100
 *   vocabulary  number  0–100
 *   grammar     number  0–100
 */

function createEvaluationDoc(sessionId, {
  userId,
  scores,
  fillerWordCount,
  fillerWords,
  strengths,
  improvements,
  recommendedNextScenarioId,
  rawTranscript,
}) {
  return {
    sessionId,
    userId,
    generatedAt: FieldValue.serverTimestamp(),
    scores,
    fillerWordCount,
    fillerWords,
    strengths,
    improvements,
    recommendedNextScenarioId,
    rawTranscript,
  };
}

module.exports = { createEvaluationDoc };
