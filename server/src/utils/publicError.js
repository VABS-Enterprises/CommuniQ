/**
 * The error message that is safe to send to the client.
 *
 * 4xx errors carry messages written for the user (validation, "audio too
 * short" from the AI server). 5xx errors can carry internals — upstream
 * stack text, Firestore index URLs, provider responses — so they get the
 * caller's generic fallback instead — unless the thrower marked the message
 * as user-facing with `err.expose = true`. The real message is still logged.
 */
function publicError(err, fallback) {
  const status = err && err.statusCode;
  if (status && status >= 400 && status < 500 && err.message) return err.message;
  if (err && err.expose === true && err.message) return err.message;
  return fallback;
}

module.exports = { publicError };
