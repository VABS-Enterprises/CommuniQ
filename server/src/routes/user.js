const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const {
  getProfile,
  updateProfile,
  updateTrainingConsent,
  getEvaluationProfile,
  saveVisualReport,
  getVisualReports,
} = require('../controllers/userController');

router.get('/profile', verifyToken, getProfile);
router.patch('/profile', verifyToken, updateProfile);
router.patch('/training-consent', verifyToken, updateTrainingConsent);
router.get('/evaluation-profile', verifyToken, getEvaluationProfile);

router.post('/visual-reports', verifyToken, saveVisualReport);
router.get('/visual-reports', verifyToken, getVisualReports);

module.exports = router;
