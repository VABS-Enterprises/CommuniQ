const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const { verifyToken } = require('../middleware/auth');
const { saveOnboarding, getOnboarding, evaluateIntroDemo, transcribeDemo } = require('../controllers/onboardingController');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB cap
});

// Allow a few retries per window — called once per account creation
const saveLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many onboarding requests, please try again later' },
});

// Strict limiter for the unauthenticated demo evaluation endpoint
const demoLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  message: { error: 'Too many demo requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Separate limiter for transcription (slightly more generous — user may re-record)
const transcribeLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 20,
  message: { error: 'Too many transcription requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

/*
 * POST /onboarding/transcribe
 * Unauthenticated — transcribes a voice recording via Groq Whisper.
 * Used in the onboarding demo so users can speak instead of type.
 */
router.post('/transcribe', transcribeLimiter, upload.single('audio'), transcribeDemo);

/*
 * POST /onboarding/demo
 * Unauthenticated — evaluates a pre-signup intro text via AI.
 * Used in the onboarding teaser to give new users instant AI feedback.
 */
router.post('/demo', demoLimiter, evaluateIntroDemo);

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
