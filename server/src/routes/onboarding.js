const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { saveOnboarding, getOnboarding } = require('../controllers/onboardingController');

// Allow a few retries per window — called once per account creation
const saveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many onboarding requests, please try again later' },
});

/*
 * POST /onboarding
 * Save (or upsert) the user's onboarding answers after account creation.
 */
router.post('/', saveLimiter, verifyToken, saveOnboarding);

/*
 * GET /onboarding
 * Retrieve the stored onboarding profile for the authenticated user.
 */
router.get('/', verifyToken, getOnboarding);

module.exports = router;
