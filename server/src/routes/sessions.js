const router = require('express').Router();
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { verifyWorkerSecret } = require('../middleware/workerAuth');
const {
  startSession,
  sessionOpening,
  processTurn,
  endSession,
  getReport,
  abandonSession,
  getSessionHistory,
  getSession,
  getLivekitToken,
  appendLiveVoiceTurn,
  handleBotCrash,
} = require('../controllers/sessionController');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max audio
});

function handleMulterError(err, req, res, next) {
  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'Audio file too large — maximum is 10 MB' });
  }
  next(err);
}

const _sessionRateLimitOpts = (max) => ({
  windowMs: 60 * 1000,
  max,
  keyGenerator: (req) => req.uid || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down' },
});

// /turn: 30/min — well above any real conversation speed (1 turn every 2s)
const turnRateLimit = rateLimit(_sessionRateLimitOpts(30));

// /opening: 10/min — one per session start
const openingRateLimit = rateLimit(_sessionRateLimitOpts(10));

// /start: 5/min — prevents session spam / Groq bill abuse
const startRateLimit = rateLimit(_sessionRateLimitOpts(5));

// /end: 10/min — prevents evaluation endpoint abuse (each eval costs an LLM call)
const endRateLimit = rateLimit(_sessionRateLimitOpts(10));

// Static routes first — must come before /:sessionId to avoid shadowing
router.post('/start', verifyToken, startRateLimit, startSession);
// CP2: LiveKit token endpoint — Flutter calls this to join the WebRTC room
router.post('/livekit-token', verifyToken, getLivekitToken);
// Pipecat worker → Firestore (shared secret, not Firebase auth)
router.post('/internal/live-voice-turn', verifyWorkerSecret, appendLiveVoiceTurn);
// Pipecat worker → Node: notify that a bot crashed unexpectedly mid-session
router.post('/internal/bot-crash', verifyWorkerSecret, handleBotCrash);
router.post('/opening', verifyToken, openingRateLimit, sessionOpening);
router.post('/turn', verifyToken, turnRateLimit, upload.single('audioFile'), handleMulterError, processTurn);
router.post('/end', verifyToken, endRateLimit, endSession);
router.get('/history', verifyToken, getSessionHistory);

// Static routes (body-based session ID)
router.post('/abandon', verifyToken, abandonSession);

// Dynamic routes
router.get('/:sessionId', verifyToken, getSession);
router.get('/:sessionId/report', verifyToken, getReport);

module.exports = router;
