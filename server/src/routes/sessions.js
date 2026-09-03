const router = require('express').Router();
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const { verifyWorkerSecret } = require('../middleware/workerAuth');
const {
  startSession,
  sessionOpening,
  processTurn,
  processTurnStream,
  endSession,
  getReport,
  abandonSession,
  getSessionHistory,
  getSession,
  getLivekitToken,
  appendLiveVoiceTurn,
  handleBotCrash,
} = require('../controllers/sessionController');

// Only accept common audio MIME types for uploaded turn audio.
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
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max audio
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

// /livekit-token: 10/min per uid — prevents room-join/token minting abuse
const livekitTokenRateLimit = rateLimit(_sessionRateLimitOpts(10));

// Static routes first — must come before /:sessionId to avoid shadowing
router.post('/start', verifyToken, startRateLimit, startSession);
// CP2: LiveKit token endpoint — Flutter calls this to join the WebRTC room
// Rate limiter runs AFTER verifyToken so keyGenerator can key on req.uid
// (IP-based keying alone can be bypassed by rotating IPs).
router.post('/livekit-token', verifyToken, livekitTokenRateLimit, getLivekitToken);
// Pipecat worker → Firestore (shared secret, not Firebase auth)
router.post('/internal/live-voice-turn', verifyWorkerSecret, appendLiveVoiceTurn);
// Pipecat worker → Node: notify that a bot crashed unexpectedly mid-session
router.post('/internal/bot-crash', verifyWorkerSecret, handleBotCrash);
router.post('/opening', verifyToken, openingRateLimit, sessionOpening);
router.post('/turn', verifyToken, turnRateLimit, upload.single('audioFile'), handleMulterError, processTurn);

// Streamed variant of /turn — same work, NDJSON response so the client can
// play the reply as it is synthesised rather than after the last sentence.
// Shares the turn rate limit: it is the same amount of AI work.
router.post('/turn/stream', verifyToken, turnRateLimit, upload.single('audioFile'), handleMulterError, processTurnStream);
router.post('/end', verifyToken, endRateLimit, endSession);
router.get('/history', verifyToken, getSessionHistory);

// Static routes (body-based session ID)
router.post('/abandon', verifyToken, abandonSession);

// Dynamic routes
router.get('/:sessionId', verifyToken, getSession);
router.get('/:sessionId/report', verifyToken, getReport);

module.exports = router;
