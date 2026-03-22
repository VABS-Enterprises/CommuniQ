const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { register, googleSignIn, getMe, deleteAccount } = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');

// Rate limiter for registration — prevents abuse (10 attempts per 15 min)
const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Too many registration attempts, please try again later' },
});

// Rate limiter for Google sign-in (softer limit)
const googleLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { error: 'Too many sign-in attempts, please try again later' },
});

/*
 * POST /auth/register
 * Email/Password sign-up.
 * Flutter creates Firebase Auth account first, then calls this with the ID token + { name }.
 * Node creates the Firestore user document with all app-specific defaults.
 */
router.post('/register', registerLimiter, verifyToken, register);

/*
 * POST /auth/google
 * Google Sign-In (handles BOTH new and returning users).
 * Flutter signs in with Google → gets Firebase ID token → sends here.
 * Node upserts the Firestore user doc (create if new, update lastLoginAt if existing).
 */
router.post('/google', googleLimiter, verifyToken, googleSignIn);

/*
 * GET /auth/me
 * Returns the current user's full Firestore profile.
 * Flutter calls this on app start to restore user state after the token is validated.
 */
router.get('/me', verifyToken, getMe);

/*
 * DELETE /auth/account
 * Deletes all Firestore data then removes the Firebase Auth account.
 * Must be server-side — Firestore batch deletion requires Admin SDK.
 */
router.delete('/account', verifyToken, deleteAccount);

module.exports = router;
