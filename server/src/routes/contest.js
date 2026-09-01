const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { submitContestAnswer, getContestHistory, getLeaderboard } = require('../controllers/contestController');

// /contest/submit: 10/min per uid — each call costs an LLM evaluation call.
const submitRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  keyGenerator: (req) => req.uid || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down' },
});

router.post('/submit', verifyToken, submitRateLimit, submitContestAnswer);
router.get('/history', verifyToken, getContestHistory);
router.get('/leaderboard', verifyToken, getLeaderboard);

module.exports = router;
