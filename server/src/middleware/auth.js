const { auth } = require('../config/firebase');

/**
 * Verifies the Firebase ID token from the Authorization header.
 * Attaches decoded claims to req:
 *   req.uid      — Firebase Auth uid
 *   req.email    — user's email
 *   req.name     — display name (available for Google Sign-In tokens)
 *   req.picture  — profile photo URL (available for Google Sign-In tokens)
 */
async function verifyToken(req, res, next) {
  if (
    process.env.NODE_ENV !== 'production' &&
    process.env.ENABLE_DEV_AUTH_BYPASS === 'true' &&
    req.headers['x-dev-uid']
  ) {
    req.uid = req.headers['x-dev-uid'];
    req.email = req.headers['x-dev-email'] || 'dev@communiq.test';
    req.name = 'Dev User';
    req.picture = null;
    return next();
  }

  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    if (process.env.NODE_ENV !== 'production') {
      req.uid = 'guest_user_demo';
      req.email = 'guest@communiq.test';
      req.name = 'Demo User';
      return next();
    }
    return res.status(401).json({ error: 'Missing or malformed Authorization header' });
  }

  const idToken = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await auth.verifyIdToken(idToken);
    req.uid = decodedToken.uid;
    req.email = decodedToken.email;
    req.name = decodedToken.name || null;       // populated by Google Sign-In
    req.picture = decodedToken.picture || null; // populated by Google Sign-In
    next();
  } catch (err) {
    console.error('Token verification failed:', err.message);
    if (process.env.NODE_ENV !== 'production') {
      req.uid = 'guest_user_demo';
      req.email = 'guest@communiq.test';
      req.name = 'Demo User';
      return next();
    }
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { verifyToken };
