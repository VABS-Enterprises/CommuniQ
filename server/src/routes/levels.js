const router = require('express').Router();
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { evaluateLearningAnswer } = require('../services/fastApiService');

// Path to the levels JSON file at the project root.
// __dirname = server/src/routes → ../../.. = project root
const LEVELS_PATH = path.join(__dirname, '..', '..', '..', 'communiq_levels_1_20.json');

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
 * Deterministic option ordering.
 *
 * The correct answer must not be identifiable by its position, but the order
 * must also be stable — a client that re-fetches mid-level should not see the
 * options jump around. A seeded shuffle keyed on levelId+step gives both.
 */
function seededShuffle(items, seed) {
  const out = items.slice();
  // Mix the seed before use: consecutive small seeds (levelId*1000+step) leave
  // xorshift poorly diffused for the first few outputs, which skewed how often
  // the correct answer landed in position 0.
  let state = Math.imul(seed ^ 0x9e3779b9, 0x85ebca6b) >>> 0;
  state ^= state >>> 13;
  state = Math.imul(state, 0xc2b2ae35) >>> 0;
  state ^= state >>> 16;
  if (state === 0) state = 0x6d2b79f5;
  const next = () => {
    // xorshift32 — tiny, deterministic, and adequate for ordering options.
    state ^= state << 13; state >>>= 0;
    state ^= state >> 17;
    state ^= state << 5; state >>>= 0;
    return state;
  };
  for (let i = out.length - 1; i > 0; i--) {
    const j = next() % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/*
 * Strips the answer key out of a level before it goes over the wire.
 *
 * The client needs the question and its options to render the step; it must
 * not learn which option is correct, nor the per-outcome feedback (which would
 * leak the answer just as effectively). Grading happens in
 * learningController.submitAnswer, which returns the right feedback string.
 */
function sanitizeLevel(level) {
  const mcqs = Array.isArray(level.mcqs) ? level.mcqs : [];
  return {
    ...level,
    mcqs: mcqs.map((m) => {
      const options = seededShuffle(
        [m.correct_option, ...(m.incorrect_options || [])],
        (level.id * 1000) + (m.step || 1)
      );
      return { step: m.step, question: m.question, options };
    }),
  };
}

let _sanitizedCache = null;

router.get('/', verifyToken, async (req, res) => {
  try {
    if (_sanitizedCache) return res.status(200).json(_sanitizedCache);

    if (!fs.existsSync(LEVELS_PATH)) {
      console.error(`Levels file not found at ${LEVELS_PATH}`);
      return res.status(404).json({ error: 'Levels data not found on server' });
    }

    const rawData = fs.readFileSync(LEVELS_PATH, 'utf8');
    const data = JSON.parse(rawData);
    const levels = Array.isArray(data.levels) ? data.levels : [];

    _sanitizedCache = { ...data, levels: levels.map(sanitizeLevel) };
    return res.status(200).json(_sanitizedCache);
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
