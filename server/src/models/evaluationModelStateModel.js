const { FieldValue } = require('firebase-admin/firestore');
const { DIMENSIONS, DEFAULT_ALPHA, DEFAULT_TARGET_PERCENTILE, FIXED_BASELINE_THETA } = require('../services/evaluationModelConstants');

/*
 * Firestore shape — evaluationModel/{scenarioType}
 * ─────────────────────────────────────────────────
 * One doc per scenario type (e.g. "hr_interview", "sales"), plus a pooled
 * "global" doc used as a fallback when a specific scenario type doesn't yet
 * have enough population data. Written only by evaluationModelService's
 * Loop A retraining job — never read/written directly by request handlers.
 *
 * scenarioType          string
 * updatedAt             timestamp
 * cycle                 number    t — increments by 1 each retraining cycle
 * alpha                 number    exponential-smoothing constant, α ∈ (0,1)
 * targetPercentile      number    population percentile θ tracks, e.g. 60
 * sampleSizeLastCycle   number    evaluationReports used in the most recent cycle
 * dimensions            object    per-dimension state, keyed by dimension name:
 *   theta               number    θ_{d,t} — current adaptive threshold (0–100)
 *   w                    number    w_{d,t} — current dimension weight (sums to 1 across dims)
 *   percentiles          object    { p10, p25, p40, p50, p60, p75, p90 } snapshot
 *   mean                 number    population mean this cycle
 *   stdev                number    population stdev this cycle
 * history               array     capped at last 52 entries (~1yr weekly cadence)
 *   { cycle, computedAt, sampleSize, thetas: {dim:number}, weights: {dim:number} }
 */

function createEvaluationModelStateDoc(scenarioType) {
  const dimensions = {};
  for (const dim of DIMENSIONS) {
    dimensions[dim] = {
      theta: FIXED_BASELINE_THETA,
      w: 1 / DIMENSIONS.length,
      percentiles: null,
      mean: null,
      stdev: null,
    };
  }
  return {
    scenarioType,
    updatedAt: FieldValue.serverTimestamp(),
    cycle: 0,
    alpha: DEFAULT_ALPHA,
    targetPercentile: DEFAULT_TARGET_PERCENTILE,
    sampleSizeLastCycle: 0,
    dimensions,
    history: [],
  };
}

module.exports = { createEvaluationModelStateDoc };
