const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { getProgress, submitAnswer, completeLevel } = require('../controllers/learningController');

router.use(verifyToken);

// Generous per-uid limiter — grading is cheap (in-memory JSON lookup + one
// Firestore transaction) but this still guards against runaway/buggy clients.
const answerRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: (req) => req.uid,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down' },
});

/*
 * GET /learning/progress
 * Returns the authenticated user's learning-module coin balance, completed
 * level ids, and per-step correctness map.
 */
router.get('/progress', getProgress);

/*
 * POST /learning/answer
 * Body: { levelId: number, step: number, selectedOption: string }
 * Server-authoritative MCQ grading — looks up the correct option from
 * learningLevels.json, tracks attempt count itself, and awards coins.
 */
router.post('/answer', answerRateLimit, submitAnswer);

/*
 * POST /learning/levels/:levelId/complete
 * Server verifies every MCQ step in the level was answered correctly before
 * marking it complete — the client cannot just claim completion.
 */
router.post('/levels/:levelId/complete', completeLevel);

module.exports = router;
