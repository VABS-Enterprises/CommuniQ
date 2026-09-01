const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — evaluationReports/{sessionId}
 * ─────────────────────────────────────────────────
 * sessionId                  string
 * userId                     string    ref → users/{uid}
 * scenarioType               string    e.g. "hr_interview", "custom" — used by the
 *                                      self-learning evaluation model to group
 *                                      population statistics (see evaluationModelService.js)
 * generatedAt                timestamp
 * scores                     Scores
 * fillerWordCount            number
 * fillerWords                string[]  e.g. ["um", "uh", "basically"]
 * strengths                  string[]  exactly 2 items
 * improvements               string[]  exactly 2 items
 * recommendedNextType        string
 * rawTranscript              string    full conversation as plain text
 * adaptive                   object    self-learning evaluation model output (paper §3.4)
 *   cycleUsed                number    which evaluationModel.cycle these thresholds came from
 *   thetaAtEval              {dim:number}  per-dimension threshold θ_{d,t} used
 *   weightAtEval             {dim:number}  per-dimension weight w_{d,t} used
 *   userRollingMean          {dim:number}  μ_{i,d} over the user's last-k sessions (null if cold-start)
 *   deficit                  {dim:number}  θ_{d,t} − μ_{i,d}, the feedback-ranking key
 *   personalizedBar          {dim:number}  per-user locally-adjusted threshold
 *   adaptiveScore            number    weighted, personalized 0–100 overall score
 *   feedbackRank             string[]  dimension names ranked by deficit, filtered to
 *                                      recurring weaknesses (top priority first)
 *   suppressedIssues         string[]  dimension names flagged low but not recurring
 *                                      across the last-k sessions (treated as one-offs)
 *   coldStart                boolean   true if population and/or user history was
 *                                      below the minimum sample size for this eval
 *
 * Scores shape:
 *   clarity       number  0–100
 *   fluency       number  0–100
 *   confidence    number  0–100
 *   vocabulary    number  0–100
 *   grammar       number  0–100
 *   pronunciation number  0–100  (inferred from Whisper transcript quality)
 */

function createEvaluationDoc(sessionId, {
  userId,
  scenarioType,
  scores,
  fillerWordCount,
  fillerWords,
  strengths,
  improvements,
  recommendedNextType,
  rawTranscript,
  adaptive,
}) {
  return {
    sessionId,
    userId,
    scenarioType: scenarioType || 'custom',
    generatedAt: FieldValue.serverTimestamp(),
    scores,
    fillerWordCount,
    fillerWords,
    strengths,
    improvements,
    recommendedNextType,
    rawTranscript,
    // Additive, optional — absent (undefined) on any caller that hasn't been
    // updated yet, so this never breaks a doc write from older code.
    ...(adaptive ? { adaptive } : {}),
  };
}

module.exports = { createEvaluationDoc };
