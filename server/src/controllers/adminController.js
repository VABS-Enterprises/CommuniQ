const { retrainAllScenarioTypes } = require('../services/evaluationModelService');
const { getEvaluationModelDoc } = require('../services/firestoreService');
const { DIMENSIONS } = require('../services/evaluationModelConstants');

// POST /admin/evaluation-model/retrain
// Manually forces a Loop A retraining cycle, bypassing the weekly cadence check.
// For testing/QA and for recovering from a bad cycle.
async function forceRetrain(req, res) {
  try {
    const results = await retrainAllScenarioTypes();
    return res.status(200).json({
      scenarioTypes: Object.keys(results),
      results,
    });
  } catch (err) {
    console.error('forceRetrain error:', err.message);
    return res.status(500).json({ error: 'Retrain failed' });
  }
}

// GET /admin/evaluation-model/state
// Inspect current θ/w per scenario type (+ global) without a Firestore console.
// Optional ?scenarioType= to fetch just one.
async function getEvaluationModelState(req, res) {
  const { scenarioType } = req.query;

  try {
    if (scenarioType) {
      const doc = await getEvaluationModelDoc(scenarioType);
      if (!doc) return res.status(404).json({ error: `No evaluation model state for '${scenarioType}' yet` });
      return res.status(200).json({ dimensions: DIMENSIONS, state: doc });
    }

    // No index of known scenario types exists yet — 'global' is always present
    // once at least one retrain has run; per-type docs are looked up on demand.
    const global = await getEvaluationModelDoc('global');
    return res.status(200).json({
      dimensions: DIMENSIONS,
      global: global || null,
      note: global
        ? 'Pass ?scenarioType=<type> to inspect a specific scenario type.'
        : 'No retraining cycle has run yet — the fixed baseline rubric (θ=60, uniform weights) is in effect.',
    });
  } catch (err) {
    console.error('getEvaluationModelState error:', err.message);
    return res.status(500).json({ error: 'Could not fetch evaluation model state' });
  }
}

module.exports = { forceRetrain, getEvaluationModelState };
