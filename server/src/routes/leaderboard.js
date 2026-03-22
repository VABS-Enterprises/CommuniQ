const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const { getLeaderboard, getWeeklyLeaderboard } = require('../controllers/leaderboardController');

// Static route first to avoid /weekly being caught by a future /:id pattern
router.get('/weekly', verifyToken, getWeeklyLeaderboard);
router.get('/', verifyToken, getLeaderboard);

module.exports = router;
