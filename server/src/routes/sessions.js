const router = require('express').Router();
const multer = require('multer');
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

// Static routes first — must come before /:sessionId to avoid shadowing
router.post('/start', verifyToken, startSession);
router.post('/turn', verifyToken, upload.single('audioFile'), processTurn);
router.post('/end', verifyToken, endSession);
router.get('/history', verifyToken, getSessionHistory);

// Dynamic routes
router.get('/:sessionId', verifyToken, getSession);
router.get('/:sessionId/report', verifyToken, getReport);
router.post('/:sessionId/abandon', verifyToken, abandonSession);

module.exports = router;
