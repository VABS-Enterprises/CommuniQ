/**
 * Stale session cleanup job.
 *
 * Runs every INTERVAL_MS (default 30 minutes) and abandons any session that
 * has been 'in_progress' for longer than MAX_AGE_MS (default 2 hours).
 *
 * Why this is needed:
 *   - App crash / hard network drop on the client means POST /sessions/end is
 *     never called, leaving the session stuck in 'in_progress' forever.
 *   - The Pipecat bot may have already exited (via on_participant_left or crash),
 *     but the Firestore document is never updated without an explicit /end call.
 *   - LiveKit rooms are not automatically deleted by the LiveKit server, so
 *     orphan rooms accumulate until this job cleans them up.
 *
 * Safety:
 *   - Only touches sessions older than MAX_AGE_MS — well beyond any legitimate
 *     session (typical sessions are 5–15 minutes).
 *   - Marks as 'abandoned', not deleted — the turns[] and metadata are preserved
 *     for debugging / admin review.
 *   - Uses the same abandonSession() + deleteRoom() path as the normal abandon
 *     flow so the Firestore state is consistent.
 *   - Errors per-session are caught individually so one bad document doesn't
 *     prevent other stale sessions from being cleaned up.
 */

const { getStaleInProgressSessions, abandonSession } = require('./firestoreService');
const livekit = require('./livekitService');

const INTERVAL_MS  = 30 * 60 * 1000;  // run every 30 minutes
const MAX_AGE_MS   =  2 * 60 * 60 * 1000;  // abandon sessions older than 2 hours

async function runCleanup() {
  let staleSessions;
  try {
    staleSessions = await getStaleInProgressSessions(MAX_AGE_MS);
  } catch (err) {
    console.error('[staleSessionJob] Failed to query stale sessions:', err.message);
    return;
  }

  if (staleSessions.length === 0) {
    console.log('[staleSessionJob] No stale sessions found.');
    return;
  }

  console.log(`[staleSessionJob] Found ${staleSessions.length} stale session(s) — cleaning up.`);

  const results = await Promise.allSettled(
    staleSessions.map(async (session) => {
      const sessionId = session.id || session.sessionId;
      try {
        await abandonSession(sessionId);
        await livekit.deleteRoom(sessionId);
        console.log(`[staleSessionJob] Abandoned stale session: ${sessionId}`);
      } catch (err) {
        console.error(`[staleSessionJob] Failed to abandon session ${sessionId}:`, err.message);
        throw err;
      }
    })
  );

  const failed = results.filter((r) => r.status === 'rejected').length;
  if (failed > 0) {
    console.error(`[staleSessionJob] ${failed} session(s) failed to clean up.`);
  }
}

/**
 * Start the stale session cleanup job.
 * Called once at server startup. The first run is delayed by INTERVAL_MS so
 * it doesn't fire during the cold-start window when Firestore may not be ready.
 */
function startStaleSessionJob() {
  console.log(
    `[staleSessionJob] Started — will run every ${INTERVAL_MS / 60_000} minutes, ` +
    `abandoning sessions older than ${MAX_AGE_MS / 3_600_000} hours.`
  );
  setInterval(runCleanup, INTERVAL_MS);
}

module.exports = { startStaleSessionJob };
