/**
 * Shared secret for Pipecat worker → Node internal routes (no Firebase token).
 * Set PIPECAT_WEBHOOK_SECRET in server/.env to the same value as the worker.
 */
function verifyWorkerSecret(req, res, next) {
  const expected = process.env.PIPECAT_WEBHOOK_SECRET;
  if (!expected || expected.length < 16) {
    return res.status(503).json({
      error:
        'PIPECAT_WEBHOOK_SECRET is not set (or too short) on the Node server. ' +
        'Add it to .env for live-voice transcript sync.',
    });
  }
  const got = req.get('X-Communiq-Worker-Secret');
  if (got !== expected) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

module.exports = { verifyWorkerSecret };
