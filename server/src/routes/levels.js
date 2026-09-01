const router = require('express').Router();
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { evaluateLearningAnswer } = require('../services/fastApiService');

// Path to the levels JSON file at the project root.
// __dirname = server/src/routes → ../../.. = project root
const LEVELS_PATH = path.join(__dirname, '..', '..', '..', 'communiq_levels.json');

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

router.get('/', verifyToken, async (req, res) => {
  try {
    if (!fs.existsSync(LEVELS_PATH)) {
      console.error(`Levels file not found at ${LEVELS_PATH}`);
      return res.status(404).json({ error: 'Levels data not found on server' });
    }

    const rawData = fs.readFileSync(LEVELS_PATH, 'utf8');
    const data = JSON.parse(rawData);

    return res.status(200).json(data);
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
