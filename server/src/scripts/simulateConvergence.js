/**
 * Drives several Loop A retraining cycles back-to-back against a fixed
 * synthetic population distribution and checks that θ (the adaptive threshold)
 * converges toward the true target-percentile value, damped by α — i.e. that
 * exponential smoothing actually smooths rather than just tracking the raw
 * percentile 1:1.
 *
 * Generates synthetic score arrays in memory (no evaluationReports are
 * written) — only the evaluationModel/{scenarioType} state doc is touched,
 * and it's deleted again at the end.
 *
 * Usage: node src/scripts/simulateConvergence.js
 */

require('dotenv').config();
const { db } = require('../config/firebase');
const { retrainCycle } = require('../services/evaluationModelService');
const { DIMENSIONS } = require('../services/evaluationModelConstants');

const SCENARIO_TYPE = 'test_convergence';
const CYCLES = 10;
const SAMPLE_SIZE = 200;
const TARGET_MEAN = 70;
const TARGET_STDEV = 12;
const CONVERGENCE_EPSILON = 3; // points

function randomScore(mean, stdev) {
  let u = 0, v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  return Math.max(0, Math.min(100, mean + z * stdev));
}

function generateReports(mean, stdev, count) {
  return Array.from({ length: count }, () => {
    const scores = {};
    for (const dim of DIMENSIONS) scores[dim] = randomScore(mean, stdev);
    return { scores };
  });
}

async function reset() {
  await db.collection('evaluationModel').doc(SCENARIO_TYPE).delete().catch(() => {});
}

async function main() {
  const target = TARGET_MEAN + TARGET_STDEV * 0.2533; // ~inverse-normal CDF(0.6)
  console.log(`Simulating ${CYCLES} Loop A retraining cycles for a fixed normal(${TARGET_MEAN}, ${TARGET_STDEV}) population...`);
  console.log(`Expected theta (60th percentile) to converge toward ~${target.toFixed(1)} for each dimension.\n`);

  await reset();

  const trajectory = [];
  const weightSums = [];
  for (let cycle = 0; cycle < CYCLES; cycle++) {
    const reports = generateReports(TARGET_MEAN, TARGET_STDEV, SAMPLE_SIZE);
    const doc = await retrainCycle(SCENARIO_TYPE, reports);
    const theta = doc.dimensions.clarity.theta;
    const wSum = DIMENSIONS.reduce((s, d) => s + doc.dimensions[d].w, 0);
    trajectory.push(theta);
    weightSums.push(Math.round(wSum * 10000) / 10000);
    console.log(`Cycle ${cycle}: clarity.theta=${theta}  weightSum=${weightSums[cycle]} (should be ~1.0)`);
  }

  console.log(`\nTrajectory: ${trajectory.join(' -> ')}`);
  const last = trajectory[trajectory.length - 1];
  const withinEpsilon = Math.abs(last - target) < CONVERGENCE_EPSILON;
  console.log(
    withinEpsilon
      ? `PASS: converged — final theta=${last} is within ${CONVERGENCE_EPSILON} points of the target ~${target.toFixed(1)}.`
      : `FAIL: did not converge within epsilon — final theta=${last}, target ~${target.toFixed(1)}. Check alpha/cadence.`
  );

  const weightsOk = weightSums.every((s) => Math.abs(s - 1) < 0.01);
  console.log(weightsOk ? 'PASS: dimension weights sum to ~1 every cycle.' : 'FAIL: dimension weights did not sum to 1 in every cycle.');

  await reset();
  process.exit(withinEpsilon && weightsOk ? 0 : 1);
}

main().catch((err) => {
  console.error('Simulation failed:', err);
  process.exit(1);
});
