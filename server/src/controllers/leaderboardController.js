const { getTopUsersByXp, getWeeklyTopUsersByXp } = require('../services/firestoreService');

// GET /leaderboard
async function getLeaderboard(req, res) {
  try {
    const users = await getTopUsersByXp(50);
    return res.status(200).json({ leaderboard: users });
  } catch (err) {
    console.error('getLeaderboard error:', err.message);
    return res.status(500).json({ error: 'Could not fetch leaderboard' });
  }
}

// GET /leaderboard/weekly
async function getWeeklyLeaderboard(req, res) {
  try {
    const users = await getWeeklyTopUsersByXp(50);
    return res.status(200).json({ leaderboard: users });
  } catch (err) {
    console.error('getWeeklyLeaderboard error:', err.message);
    return res.status(500).json({ error: 'Could not fetch weekly leaderboard' });
  }
}

module.exports = { getLeaderboard, getWeeklyLeaderboard };
