const router = require('express').Router();
const fs = require('fs');
const path = require('path');
const { verifyToken } = require('../middleware/auth');

// Path to the levels JSON file at the project root.
// __dirname = server/src/routes → ../../.. = project root
const LEVELS_PATH = path.join(__dirname, '..', '..', '..', 'communiq_levels.json');

router.get('/', verifyToken, async (req, res) => {
  try {
    if (!fs.existsSync(LEVELS_PATH)) {
      console.error(`Levels file not found at ${LEVELS_PATH}`);
      return res.status(404).json({ error: 'Levels data not found on server' });
    }

    const rawData = fs.readFileSync(LEVELS_PATH, 'utf8');
    const data = JSON.parse(rawData);

    // Optional: could filter by user level here if desired
    // For now, return all levels as requested.
    return res.status(200).json(data);
  } catch (err) {
    console.error('getLevels error:', err.message);
    return res.status(500).json({ error: 'Could not fetch levels' });
  }
});

module.exports = router;
