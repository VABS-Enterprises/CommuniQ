const { FieldValue } = require('firebase-admin/firestore');
const {
  getEvaluationModelDoc,
  setEvaluationModelDoc,
  getRecentEvaluationReportsAll,
} = require('./firestoreService');
const { createEvaluationModelStateDoc } = require('../models/evaluationModelStateModel');
const {
  DIMENSIONS,
  DEFAULT_ALPHA,
  DEFAULT_TARGET_PERCENTILE,
  FIXED_BASELINE_THETA,
  MIN_POPULATION_SAMPLE,
  MAX_POPULATION_SAMPLE,
  POPULATION_LOOKBACK_MS,
  USER_HISTORY_WINDOW,
  MIN_USER_HISTORY,
  DEFICIT_MARGIN,
  RAISE_CAP,
  LENIENCY_CAP,
} = require('./evaluationModelConstants');

/**
 * Self-learning evaluation model (paper §3.4).
 *
 * Loop A (population retraining, slow cadence — driven by evaluationModelJob.js):
 *   retrainAllScenarioTypes() / retrainCycle() recompute per-dimension thresholds
 *   θ_{d,t} and weights w_{d,t} from the population score distribution.
 *
 * Loop B (per-session personalization, every session — called from sessionController):
 *   personalizeEvaluation() compares a user's rolling mean μ_{i,d} against the
 *   current θ_{d,t}, derives a personalized bar, ranks feedback by deficit, and
 *   suppresses one-off (non-recurring) weaknesses.
 *
 * ai-server stays fully stateless — everything here treats its raw 0–100 rubric
 * score as a fixed measurement and adapts around it in Node, which already owns
 * Firestore and the per-session/per-user history this model needs.
 */

// ─── shared math helpers ────────────────────────────────────────────────────

function round2(x) {
  return x == null ? null : Math.round(x * 100) / 100;
}

function round4(x) {
  return x == null ? null : Math.round(x * 10000) / 10000;
}

function mean(arr) {
  return arr.reduce((s, v) => s + v, 0) / arr.length;
}

function stdev(arr, m) {
  const mu = m != null ? m : mean(arr);
  const variance = arr.reduce((s, v) => s + (v - mu) ** 2, 0) / arr.length;
  return Math.sqrt(variance);
}

/** Percentile of a value already-sorted ascending, via linear interpolation. */
function percentile(sortedArr, p) {
  if (!sortedArr || sortedArr.length === 0) return null;
  if (sortedArr.length === 1) return sortedArr[0];
  const idx = (p / 100) * (sortedArr.length - 1);
  const lo = Math.floor(idx);
  const hi = Math.ceil(idx);
  if (lo === hi) return sortedArr[lo];
  const frac = idx - lo;
  return sortedArr[lo] + (sortedArr[hi] - sortedArr[lo]) * frac;
}

function computeDimensionStats(sortedValues, targetPercentile) {
  if (!sortedValues || sortedValues.length === 0) {
    return { percentiles: null, mean: null, stdev: null, targetValue: null };
  }
  const percentiles = {};
  for (const p of [10, 25, 40, 50, 60, 75, 90]) {
    percentiles[`p${p}`] = round2(percentile(sortedValues, p));
  }
  const m = mean(sortedValues);
  const sd = stdev(sortedValues, m);
  const targetValue = percentile(sortedValues, targetPercentile);
  return { percentiles, mean: m, stdev: sd, targetValue };
}

// ─── Loop A — population retraining ─────────────────────────────────────────

/**
 * Recomputes θ_{d,t} and w_{d,t} for one scenario type (or 'global', pooling
 * every scenario type) from an already-fetched batch of evaluationReports.
 *
 * θ_new = α·θ_old + (1−α)·f(P_t)   where f(P_t) is this cycle's value at the
 * target percentile of the population score distribution for that dimension.
 *
 * Weights are updated the same way, seeded from a raw "how discriminative is
 * this dimension" signal: dimensions with a wider population spread (higher
 * stdev) carry more scoring signal and get relatively more weight; dimensions
 * where nearly everyone scores the same carry less. Weights are renormalized
 * to sum to 1 after smoothing.
 */
async function retrainCycle(scenarioType, reports) {
  const prevState = await getEvaluationModelDoc(scenarioType);
  const alpha = prevState?.alpha ?? DEFAULT_ALPHA;
  const targetPercentile = prevState?.targetPercentile ?? DEFAULT_TARGET_PERCENTILE;
  const cycle = (prevState?.cycle ?? -1) + 1;
  const sampleSize = reports.length;

  const perDim = {};
  const rawWeights = {};
  for (const dim of DIMENSIONS) {
    const values = reports
      .map((r) => r.scores?.[dim])
      .filter((v) => typeof v === 'number')
      .sort((a, b) => a - b);
    const stats = computeDimensionStats(values, targetPercentile);
    const prevTheta = prevState?.dimensions?.[dim]?.theta ?? FIXED_BASELINE_THETA;
    const fP = stats.targetValue != null ? stats.targetValue : FIXED_BASELINE_THETA;
    const theta = values.length > 0 ? alpha * prevTheta + (1 - alpha) * fP : prevTheta;
    perDim[dim] = { theta, stats };
    rawWeights[dim] = values.length > 0 && stats.stdev > 0.01 ? 1 / stats.stdev : 1 / DIMENSIONS.length;
  }

  const rawWSum = Object.values(rawWeights).reduce((s, v) => s + v, 0) || 1;
  for (const dim of DIMENSIONS) {
    const prevW = prevState?.dimensions?.[dim]?.w ?? 1 / DIMENSIONS.length;
    const normalizedRawW = rawWeights[dim] / rawWSum;
    perDim[dim].wRaw = alpha * prevW + (1 - alpha) * normalizedRawW;
  }
  const wSum = DIMENSIONS.reduce((s, d) => s + perDim[d].wRaw, 0) || 1;

  const dimensionsOut = {};
  for (const dim of DIMENSIONS) {
    const { theta, stats, wRaw } = perDim[dim];
    dimensionsOut[dim] = {
      theta: round2(theta),
      w: round4(wRaw / wSum),
      percentiles: stats.percentiles,
      mean: stats.mean != null ? round2(stats.mean) : null,
      stdev: stats.stdev != null ? round2(stats.stdev) : null,
    };
  }

  const historyEntry = {
    cycle,
    computedAt: Date.now(),
    sampleSize,
    thetas: Object.fromEntries(DIMENSIONS.map((d) => [d, dimensionsOut[d].theta])),
    weights: Object.fromEntries(DIMENSIONS.map((d) => [d, dimensionsOut[d].w])),
  };
  const history = [...(prevState?.history || []), historyEntry].slice(-52);

  const newDoc = {
    ...(prevState || createEvaluationModelStateDoc(scenarioType)),
    scenarioType,
    updatedAt: FieldValue.serverTimestamp(),
    cycle,
    alpha,
    targetPercentile,
    sampleSizeLastCycle: sampleSize,
    dimensions: dimensionsOut,
    history,
  };
  await setEvaluationModelDoc(scenarioType, newDoc);
  return newDoc;
}

/**
 * Runs one full Loop A retraining pass: a single Firestore read of all recent
 * evaluationReports, grouped in memory by scenarioType, plus one pooled
 * 'global' retrain across every type (used as the fallback tier).
 */
async function retrainAllScenarioTypes() {
  const allReports = await getRecentEvaluationReportsAll(POPULATION_LOOKBACK_MS, MAX_POPULATION_SAMPLE);

  const byType = new Map();
  for (const r of allReports) {
    const type = r.scenarioType || 'custom';
    if (!byType.has(type)) byType.set(type, []);
    byType.get(type).push(r);
  }

  const results = {};
  results.global = await retrainCycle('global', allReports);
  for (const [type, reports] of byType.entries()) {
    if (type === 'global') continue;
    try {
      results[type] = await retrainCycle(type, reports);
    } catch (err) {
      console.error(`[evaluationModelService] retrainCycle failed for scenarioType=${type}:`, err.message);
    }
  }
  return results;
}

// ─── Cold-start / state lookup (used by Loop B) ────────────────────────────

const HARD_DEFAULT_STATE = Object.freeze({
  scenarioType: 'default',
  cycle: 0,
  dimensions: Object.fromEntries(
    DIMENSIONS.map((d) => [d, { theta: FIXED_BASELINE_THETA, w: 1 / DIMENSIONS.length }])
  ),
});

/**
 * Three-tier fallback cascade, self-healing as data accumulates:
 * scenario-specific model → pooled global model → hardcoded fixed rubric.
 */
async function getEvaluationModelState(scenarioType) {
  const specific = scenarioType && scenarioType !== 'global' ? await getEvaluationModelDoc(scenarioType) : null;
  if (specific && (specific.sampleSizeLastCycle || 0) >= MIN_POPULATION_SAMPLE) {
    return { state: specific, coldStart: false };
  }
  const global = await getEvaluationModelDoc('global');
  if (global && (global.sampleSizeLastCycle || 0) >= MIN_POPULATION_SAMPLE) {
    return { state: global, coldStart: false };
  }
  return { state: HARD_DEFAULT_STATE, coldStart: true };
}

// ─── Loop B — per-session personalization ──────────────────────────────────

function computeRollingMean(window) {
  if (!window || window.length === 0) return null;
  return mean(window);
}

/** A dimension is "recurring" if it scored below θ in ≥2 of the last k sessions. */
function isRecurring(window, theta) {
  if (!window || window.length === 0) return false;
  return window.filter((v) => v < theta).length >= 2;
}

/**
 * Locally-raised bar for a consistently-strong user; lenient bar for a
 * transient (non-persistent) dip; unchanged bar for a persistent weakness
 * or a user within the margin of the population threshold.
 */
function computePersonalizedBar(theta, mu, window) {
  if (mu == null) return theta;
  const delta = mu - theta;
  if (delta > DEFICIT_MARGIN) {
    return theta + Math.min(delta * 0.5, RAISE_CAP);
  }
  if (delta < -DEFICIT_MARGIN) {
    const w = window || [];
    const belowCount = w.filter((v) => v < theta).length;
    const isPersistent = belowCount >= Math.ceil(w.length / 2);
    if (isPersistent) return theta; // hold the line on a chronic weakness
    return theta - Math.min(Math.abs(delta) * 0.3, LENIENCY_CAP); // one-off dip, be lenient
  }
  return theta;
}

/**
 * Computes the full Loop B personalization block for one session's raw scores.
 * Returns the legacy flat overall score (unchanged behavior for XP/back-compat),
 * the updated per-dimension rolling-history windows to persist on the user doc,
 * and the `adaptive` block to persist on the evaluationReport doc.
 */
async function personalizeEvaluation({ scenarioType, scores, strengths, improvements, user }) {
  const { state: modelState, coldStart: modelColdStart } = await getEvaluationModelState(scenarioType);
  const skillHistory = user?.skillHistory || {};
  const userColdStart = DIMENSIONS.every((d) => (skillHistory[d]?.window?.length || 0) < MIN_USER_HISTORY);

  const thetaAtEval = {};
  const weightAtEval = {};
  const userRollingMean = {};
  const deficit = {};
  const personalizedBar = {};
  const updatedSkillHistory = {};
  const recurringDims = new Set();

  for (const dim of DIMENSIONS) {
    const theta = modelState.dimensions?.[dim]?.theta ?? FIXED_BASELINE_THETA;
    const w = modelState.dimensions?.[dim]?.w ?? 1 / DIMENSIONS.length;
    const prevWindow = skillHistory[dim]?.window || [];
    const mu = computeRollingMean(prevWindow);

    thetaAtEval[dim] = round2(theta);
    weightAtEval[dim] = round4(w);
    userRollingMean[dim] = mu != null ? round2(mu) : null;
    deficit[dim] = round2(theta - (mu != null ? mu : theta));
    personalizedBar[dim] = round2(computePersonalizedBar(theta, mu, prevWindow));
    if (isRecurring(prevWindow, theta)) recurringDims.add(dim);

    const rawScore = scores?.[dim];
    const newWindow = typeof rawScore === 'number'
      ? [...prevWindow, rawScore].slice(-USER_HISTORY_WINDOW)
      : prevWindow;
    updatedSkillHistory[dim] = { window: newWindow, updatedAt: Date.now() };
  }

  // Deficit-ranked feedback (paper: rank by θ_{d,t} − μ_{i,d}, descending),
  // filtered to dimensions that actually recur — a single bad session
  // shouldn't get top billing as "your priority weakness."
  const feedbackRankAll = [...DIMENSIONS].sort((a, b) => deficit[b] - deficit[a]);
  const priorityDims = feedbackRankAll.filter((d) => recurringDims.has(d));
  const suppressedIssues = feedbackRankAll.filter((d) => !recurringDims.has(d));
  // Never surface zero feedback — fall back to the single biggest deficit.
  const feedbackRank = (priorityDims.length > 0 ? priorityDims : [feedbackRankAll[0]]).slice(0, 2);

  // Adaptive overall score: re-express each raw score against the user's own
  // personalized bar (bar = 50 on a 0-100 scale), weighted by w_{d,t}.
  let adaptiveScore = 0;
  let weightSum = 0;
  for (const dim of DIMENSIONS) {
    const raw = scores?.[dim];
    if (typeof raw !== 'number') continue;
    const bar = personalizedBar[dim];
    const denom = Math.max(1, 100 - bar);
    const rescaled = Math.max(0, Math.min(100, ((raw - bar) / denom) * 100 + 50));
    adaptiveScore += weightAtEval[dim] * rescaled;
    weightSum += weightAtEval[dim];
  }
  if (weightSum > 0) adaptiveScore = adaptiveScore / weightSum;

  const legacyOverallScore = (() => {
    const values = Object.values(scores || {}).filter((v) => typeof v === 'number');
    return values.length > 0 ? Math.round(values.reduce((s, v) => s + v, 0) / values.length) : null;
  })();

  return {
    legacyOverallScore,
    rankedStrengths: strengths || [],
    rankedImprovements: improvements || [],
    updatedSkillHistory,
    adaptiveBlock: {
      cycleUsed: modelState.cycle ?? 0,
      thetaAtEval,
      weightAtEval,
      userRollingMean,
      deficit,
      personalizedBar,
      adaptiveScore: round2(adaptiveScore),
      feedbackRank,
      suppressedIssues,
      coldStart: modelColdStart || userColdStart,
    },
  };
}

module.exports = {
  // Loop A
  retrainCycle,
  retrainAllScenarioTypes,
  // Loop B
  getEvaluationModelState,
  personalizeEvaluation,
  // exported for the synthetic-data test scripts
  computeDimensionStats,
  percentile,
};
