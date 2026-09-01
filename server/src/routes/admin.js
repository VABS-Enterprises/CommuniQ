const router = require('express').Router();
const { adminAuth } = require('../middleware/adminAuth');
const { forceRetrain, getEvaluationModelState } = require('../controllers/adminController');

router.post('/evaluation-model/retrain', adminAuth, forceRetrain);
router.get('/evaluation-model/state', adminAuth, getEvaluationModelState);

module.exports = router;
