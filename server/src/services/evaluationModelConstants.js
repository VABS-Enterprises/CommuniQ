/**
 * Shared configuration for the self-learning evaluation model (paper §3.4).
 * Centralised so the state-doc factory, the retraining job, and the
 * per-session personalization logic all agree on the same knobs.
 */

// Matches the 6 dimensions actually produced by ai-server's roleplay evaluator
// (the paper describes 5; the implemented evaluator adds "pronunciation").
const DIMENSIONS = ['clarity', 'fluency', 'confidence', 'vocabulary', 'grammar', 'pronunciation'];

// Loop A (population retraining) knobs
const DEFAULT_ALPHA = 0.7; // high alpha = slow-drifting rubric; retraining only runs weekly
const DEFAULT_TARGET_PERCENTILE = 60; // paper's example target percentile
const FIXED_BASELINE_THETA = 60; // cycle-0 / cold-start seed for every dimension
const MIN_POPULATION_SAMPLE = 30; // below this, fall back to the next tier (see getEvaluationModelState)
const MAX_POPULATION_SAMPLE = 2000; // cap on reports read per retraining cycle (cost guard)
const POPULATION_LOOKBACK_MS = 90 * 24 * 60 * 60 * 1000; // 90 days
const RETRAIN_INTERVAL_MS = Number(process.env.EVAL_MODEL_RETRAIN_INTERVAL_MS) || 7 * 24 * 60 * 60 * 1000; // weekly

// Loop B (per-session personalization) knobs
const USER_HISTORY_WINDOW = 5; // k — rolling window size for μ_{i,d}
const MIN_USER_HISTORY = 2; // sessions needed before personalization kicks in
const DEFICIT_MARGIN = 8; // |μ − θ| below this = "within margin", no personalization
const RAISE_CAP = 15; // max points the bar is raised for a consistently-strong user
const LENIENCY_CAP = 10; // max points the bar is lowered for a one-off dip

module.exports = {
  DIMENSIONS,
  DEFAULT_ALPHA,
  DEFAULT_TARGET_PERCENTILE,
  FIXED_BASELINE_THETA,
  MIN_POPULATION_SAMPLE,
  MAX_POPULATION_SAMPLE,
  POPULATION_LOOKBACK_MS,
  RETRAIN_INTERVAL_MS,
  USER_HISTORY_WINDOW,
  MIN_USER_HISTORY,
  DEFICIT_MARGIN,
  RAISE_CAP,
  LENIENCY_CAP,
};
