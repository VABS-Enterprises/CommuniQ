const router = require('express').Router();
const { randomUUID } = require('crypto');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { evaluateLearningAnswer } = require('../services/fastApiService');
const levelsStore = require('../data/levelsStore');

// /levels/evaluate: 15/min per uid — each call costs an LLM evaluation call.
// Keyed on req.uid (runs after verifyToken) so IP rotation can't bypass it.
const evaluateRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 15,
  keyGenerator: (req) => req.uid || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down' },
});

/*
 * GET /levels  (authenticated)
 *
 * The curriculum with every answer key stripped out. Questions, options,
 * scenarios and the `teaching` block are all client-renderable; the correct
 * option and its feedback strings stay on the server (see levelsStore).
 */
router.get('/', verifyToken, async (req, res) => {
  try {
    return res.status(200).json(levelsStore.getSanitizedPayload());
  } catch (err) {
    console.error('getLevels error:', err.message);
    return res.status(500).json({ error: 'Could not fetch levels' });
  }
});

/*
 * POST /levels/evaluate  (authenticated)
 *
 * Evaluates a user's personal response to a learning module scenario.
 * Proxies to the AI server's /evaluate/learning endpoint.
 *
 * Body: { question, userResponse, topic, difficulty?, expectedKeyPoints? }
 * Returns: { scores, overallScore, strengths, improvements, feedback }
 */
router.post('/evaluate', verifyToken, evaluateRateLimit, async (req, res) => {
  const { question, userResponse, topic, difficulty, expectedKeyPoints } = req.body;

  if (typeof userResponse !== 'string' || userResponse.trim().length < 5) {
    return res.status(400).json({ error: 'Response is too short.' });
  }

  const sessionId = `learning_${randomUUID()}`;
  const resolvedDifficulty = difficulty || 'beginner';
  const resolvedTopic = topic || 'communication';
  const resolvedKeyPoints = Array.isArray(expectedKeyPoints) ? expectedKeyPoints : [];

  console.log(`[LevelsEvaluate] session=${sessionId} topic=${resolvedTopic} difficulty=${resolvedDifficulty} len=${userResponse.trim().length}`);

  try {
    const result = await evaluateLearningAnswer(
      sessionId,
      question || '',
      userResponse.trim(),
      resolvedTopic,
      resolvedDifficulty,
      resolvedKeyPoints,
    );
    console.log(`[LevelsEvaluate] ✅ session=${sessionId} overall=${result.overallScore}`);
    return res.status(200).json(result);
  } catch (err) {
    const status = err.statusCode || 502;
    console.error(`[LevelsEvaluate] ❌ session=${sessionId}: ${err.message}`);
    return res.status(status).json({ error: err.message || 'Evaluation failed. Please try again.' });
  }
});

module.exports = router;
