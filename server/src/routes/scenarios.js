const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const { adminAuth } = require('../middleware/adminAuth');
const { listScenarios, getScenario, seedScenario } = require('../controllers/scenarioController');

router.get('/', verifyToken, listScenarios);
router.get('/:scenarioId', verifyToken, getScenario);
router.post('/', adminAuth, seedScenario);

module.exports = router;
