const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const {
  getProfile,
  updateProfile,
  updateTrainingConsent,
  getEvaluationProfile,
} = require('../controllers/userController');

router.get('/profile', verifyToken, getProfile);
router.patch('/profile', verifyToken, updateProfile);
router.patch('/training-consent', verifyToken, updateTrainingConsent);
router.get('/evaluation-profile', verifyToken, getEvaluationProfile);

module.exports = router;
