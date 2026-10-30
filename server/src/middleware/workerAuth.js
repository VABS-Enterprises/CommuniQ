/**
 * Shared secret for Pipecat worker → Node internal routes (no Firebase token).
 * Set PIPECAT_WEBHOOK_SECRET in server/.env to the same value as the worker.
 */
const { timingSafeEqual } = require('crypto');

function safeEqual(a, b) {
  const ab = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

function verifyWorkerSecret(req, res, next) {
  const expected = process.env.PIPECAT_WEBHOOK_SECRET;
  if (!expected || expected.length < 16) {
    console.error('PIPECAT_WEBHOOK_SECRET is not set (or too short) — live-voice sync disabled');
    return res.status(503).json({ error: 'Live voice is not configured' });
  }
  const got = req.get('X-Communiq-Worker-Secret') || '';
  if (!safeEqual(got, expected)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

module.exports = { verifyWorkerSecret };
