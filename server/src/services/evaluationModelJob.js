/**
 * Loop A trigger plumbing for the self-learning evaluation model (paper §3.4).
 *
 * Render's free-tier dyno sleeps after ~15 minutes idle, so a pure setInterval
 * (like staleSessionJob.js) can silently skip cycles for days with no traffic.
 * This uses a hybrid trigger instead:
 *   1. Primary — a fire-and-forget check on every session end (sessionController
 *      calls triggerRetrainIfDue()), so retraining happens whenever the app has
 *      any real traffic, without adding latency to the user's request.
 *   2. Secondary — an in-process interval as a safety net for long lulls on an
 *      otherwise-warm dyno.
 *   3. Manual override — POST /admin/evaluation-model/retrain (routes/admin.js).
 *
 * All three paths funnel through checkAndRetrainIfDue(), guarded by a simple
 * in-process lock (isRetraining) plus an updatedAt-age check, so concurrent
 * triggers within the same process can't double-run a cycle.
 */

const { getEvaluationModelDoc } = require('./firestoreService');
const { retrainAllScenarioTypes } = require('./evaluationModelService');
const { RETRAIN_INTERVAL_MS } = require('./evaluationModelConstants');

const SAFETY_NET_INTERVAL_MS = 6 * 60 * 60 * 1000; // 6 hours

let isRetraining = false;

function _updatedAtMillis(doc) {
  const ts = doc?.updatedAt;
  if (!ts) return 0;
  if (typeof ts.toDate === 'function') return ts.toDate().getTime();
  if (typeof ts._seconds === 'number') return ts._seconds * 1000;
  const parsed = new Date(ts).getTime();
  return isNaN(parsed) ? 0 : parsed;
}

async function checkAndRetrainIfDue() {
  if (isRetraining) return false;
  isRetraining = true;
  try {
    const globalState = await getEvaluationModelDoc('global');
    const lastUpdated = _updatedAtMillis(globalState);
    const dueSince = Date.now() - lastUpdated;
    if (globalState && dueSince < RETRAIN_INTERVAL_MS) {
      return false; // not due yet
    }
    console.log('[evaluationModelJob] Retrain due — running Loop A retraining cycle.');
    await retrainAllScenarioTypes();
    console.log('[evaluationModelJob] Retrain complete.');
    return true;
  } catch (err) {
    console.error('[evaluationModelJob] Retrain failed:', err.message);
    return false;
  } finally {
    isRetraining = false;
  }
}

/** Fire-and-forget — never awaited by the caller, never throws. */
function triggerRetrainIfDue() {
  checkAndRetrainIfDue().catch((err) => {
    console.error('[evaluationModelJob] triggerRetrainIfDue error:', err.message);
  });
}

function startEvaluationModelJob() {
  console.log(
    `[evaluationModelJob] Started — safety-net check every ${SAFETY_NET_INTERVAL_MS / 3_600_000}h; ` +
    `retrain cadence ${RETRAIN_INTERVAL_MS / 86_400_000}d.`
  );
  setInterval(() => {
    checkAndRetrainIfDue().catch((err) => {
      console.error('[evaluationModelJob] interval error:', err.message);
    });
  }, SAFETY_NET_INTERVAL_MS);
}

module.exports = { checkAndRetrainIfDue, triggerRetrainIfDue, startEvaluationModelJob };
