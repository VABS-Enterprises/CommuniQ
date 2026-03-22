const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { register, deleteAccount } = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');

const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: { error: 'Too many registration attempts, please try again later' },
});

/*
 * POST /auth/register
 * Flutter creates the Firebase Auth account first (client SDK),
 * then calls this endpoint with the resulting ID token + { name }.
 * Node creates the Firestore user document.
 */
router.post('/register', registerLimiter, verifyToken, register);

/*
 * DELETE /auth/account
 * Requires server-side handling — batch Firestore deletion cannot
 * be done safely from Flutter.
 */
router.delete('/account', verifyToken, deleteAccount);

module.exports = router;
