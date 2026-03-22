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
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
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
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { verifyToken };
