/**
 * Startup guard for shared-secret env vars.
 *
 * Both ADMIN_SECRET (adminAuth middleware) and PIPECAT_WEBHOOK_SECRET
 * (workerAuth middleware) are plain shared-secret strings — if a deploy
 * accidentally ships with the documented .env.example placeholder still in
 * place, the "secret" is effectively public (it's committed to Git).
 *
 * This module is called once at boot from server.js. In production it
 * refuses to start with a placeholder/weak secret; outside production it
 * only logs a loud warning so local dev isn't blocked.
 */

// Keep in sync with the placeholder values documented in server/.env.example.
const KNOWN_PLACEHOLDERS = new Set([
  'REPLACE_ME_ADMIN_SECRET_CHANGE_BEFORE_DEPLOY',
  'REPLACE_ME_PIPECAT_WEBHOOK_SECRET_MIN_16_CHARS',
  // Older placeholder text kept here too, in case an existing .env was
  // copied from a previous version of .env.example.
  'change-me-to-a-long-random-secret',
  'change-me-to-a-long-random-string-at-least-16-chars',
]);

const MIN_SECRET_LENGTH = 16;

function isWeakSecret(value) {
  if (!value) return true;
  if (value.length < MIN_SECRET_LENGTH) return true;
  if (KNOWN_PLACEHOLDERS.has(value)) return true;
  if (/^(change-me|replace_me|your-|change_me|placeholder)/i.test(value)) return true;
  return false;
}

/**
 * Validates the given secrets. Logs a loud warning for any weak/placeholder
 * value. In production, throws (server.js should let this crash the boot)
 * rather than silently running with a public secret.
 */
function validateSecrets(env = process.env) {
  const isProduction = env.NODE_ENV === 'production';
  const checks = [
    { name: 'ADMIN_SECRET', value: env.ADMIN_SECRET },
    { name: 'PIPECAT_WEBHOOK_SECRET', value: env.PIPECAT_WEBHOOK_SECRET },
  ];

  const weak = checks.filter((c) => isWeakSecret(c.value));

  if (weak.length === 0) return;

  for (const c of weak) {
    console.error(
      `\n*** SECURITY WARNING *** ${c.name} is unset, too short (< ${MIN_SECRET_LENGTH} chars), ` +
        `or still set to the .env.example placeholder value. ` +
        `This secret protects admin/webhook routes — set a long random value before deploying.\n`
    );
  }

  if (isProduction) {
    throw new Error(
      `Refusing to start in production with weak/placeholder secret(s): ${weak
        .map((c) => c.name)
        .join(', ')}. Set strong values in the environment before deploying.`
    );
  }
}

module.exports = { validateSecrets, isWeakSecret };
