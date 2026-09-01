const crypto = require('crypto');

/**
 * Constant-time string comparison. Hashes both inputs to a fixed-length
 * SHA-256 digest first so crypto.timingSafeEqual (which throws on
 * unequal-length buffers) always receives equal-length input, while still
 * avoiding early-exit timing leaks on the raw secret comparison.
 */
function safeEqual(a, b) {
  const hashA = crypto.createHash('sha256').update(String(a)).digest();
  const hashB = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(hashA, hashB);
}

function adminAuth(req, res, next) {
  const secret = req.headers['x-admin-secret'];

  if (!process.env.ADMIN_SECRET) {
    console.error('ADMIN_SECRET is not set in .env');
    return res.status(500).json({ error: 'Admin routes are not configured' });
  }

  if (!secret || typeof secret !== 'string' || !safeEqual(secret, process.env.ADMIN_SECRET)) {
    return res.status(403).json({ error: 'Invalid or missing admin secret' });
  }

  next();
}

module.exports = { adminAuth };
