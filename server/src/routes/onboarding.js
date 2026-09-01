const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const { verifyToken } = require('../middleware/auth');
const { saveOnboarding, getOnboarding, evaluateIntroDemo, transcribeDemo } = require('../controllers/onboardingController');

// Only accept common audio MIME types for the uploaded demo recording.
const ALLOWED_AUDIO_MIME_TYPES = new Set([
  'audio/wav',
  'audio/x-wav',
  'audio/mpeg',
  'audio/mp4',
  'audio/webm',
  'audio/ogg',
  'audio/x-m4a',
]);

function audioFileFilter(req, file, cb) {
  if (!ALLOWED_AUDIO_MIME_TYPES.has(file.mimetype)) {
    const err = new Error(`Unsupported audio type: ${file.mimetype}`);
    err.code = 'UNSUPPORTED_MEDIA_TYPE';
    return cb(err);
  }
  cb(null, true);
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB cap
  fileFilter: audioFileFilter,
});

function handleMulterError(err, req, res, next) {
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'Audio file too large — maximum is 10 MB' });
  }
  if (err && err.code === 'UNSUPPORTED_MEDIA_TYPE') {
    return res.status(415).json({ error: err.message || 'Unsupported audio file type' });
  }
  next(err);
}

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
router.post('/transcribe', transcribeLimiter, upload.single('audio'), handleMulterError, transcribeDemo);

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
