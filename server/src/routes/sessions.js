const router = require('express').Router();
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const { verifyToken } = require('../middleware/auth');
const {
  startSession,
  processTurn,
  endSession,
  getReport,
  abandonSession,
  getSessionHistory,
  getSession,
} = require('../controllers/sessionController');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max audio
});

// Security1: rate-limit /turn per authenticated user — 30 turns/minute is well above
// any real conversation speed (1 turn every 2s) while blocking runaway abuse.
const turnRateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  keyGenerator: (req) => req.uid || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests — please slow down' },
});

// Static routes first — must come before /:sessionId to avoid shadowing
router.post('/start', verifyToken, startSession);
router.post('/turn', verifyToken, turnRateLimit, upload.single('audioFile'), processTurn);
router.post('/end', verifyToken, endSession);
router.get('/history', verifyToken, getSessionHistory);

// Static routes (body-based session ID)
router.post('/abandon', verifyToken, abandonSession);

// Dynamic routes
router.get('/:sessionId', verifyToken, getSession);
router.get('/:sessionId/report', verifyToken, getReport);

module.exports = router;
