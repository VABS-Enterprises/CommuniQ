const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — contestAttempts/{attemptId}
 * ─────────────────────────────────────────────────
 * Wires up ai-server's fully-built /evaluate/contest endpoint (debate/GD/
 * extempore/quiz scoring), which previously had no Node route calling it —
 * the client's fastApiService.evaluateContestAnswer() was defined but never
 * invoked from anywhere.
 *
 * attemptId       string
 * userId          string    ref -> users/{uid}
 * name            string    denormalised display name at submission time,
 *                           so the leaderboard doesn't need a join per row
 * contestType     string    "debate" | "gd" | "extempore" | "quiz"
 * motion          string?   debate topic / GD topic / quiz question
 * position        string?   "for" | "against" | null (n/a for gd/extempore)
 * userAnswer      string    the free-text submission that was scored
 * scores          object    { argumentation, evidence, rebuttal, delivery } (0-100)
 * overallScore    number    mean of scores, returned by ai-server
 * strengths       string[]
 * improvements    string[]
 * feedback        string
 * xpAwarded       number
 * submittedAt     timestamp
 */

function createContestAttemptDoc(attemptId, {
  userId,
  name,
  contestType,
  motion,
  position,
  userAnswer,
  scores,
  overallScore,
  strengths,
  improvements,
  feedback,
  xpAwarded,
}) {
  return {
    attemptId,
    userId,
    name: name || 'User',
    contestType,
    motion: motion || null,
    position: position || null,
    userAnswer,
    scores,
    overallScore,
    strengths,
    improvements,
    feedback,
    xpAwarded,
    submittedAt: FieldValue.serverTimestamp(),
  };
}

module.exports = { createContestAttemptDoc };
