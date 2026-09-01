/**
 * Seeds synthetic evaluationReports + user docs so the self-learning evaluation
 * model (Loop A population retraining, Loop B per-user personalization) can be
 * exercised end-to-end without a real user base.
 *
 * Usage:
 *   node src/scripts/seedSyntheticEvaluationHistory.js [--count=200] [--mean=65] [--stdev=15]
 *   node src/scripts/seedSyntheticEvaluationHistory.js --cleanup
 */

require('dotenv').config();
const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { DIMENSIONS } = require('../services/evaluationModelConstants');

const SCENARIO_TYPE = 'test_synthetic';
const NUM_USERS = 20;
const DEFAULT_COUNT = 200;

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { count: DEFAULT_COUNT, mean: 65, stdev: 15, cleanup: args.includes('--cleanup') };
  for (const arg of args) {
    const [key, val] = arg.replace(/^--/, '').split('=');
    if (key === 'count') opts.count = parseInt(val, 10);
    if (key === 'mean') opts.mean = parseFloat(val);
    if (key === 'stdev') opts.stdev = parseFloat(val);
  }
  return opts;
}

// Box-Muller transform for a normal-ish random score, clamped to [0, 100].
function randomScore(mean, stdev) {
  let u = 0, v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  const z = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  return Math.max(0, Math.min(100, Math.round(mean + z * stdev)));
}

function syntheticUserId(i) {
  return `synthetic_user_${i}`;
}

async function cleanup() {
  console.log(`🧹 Cleaning up synthetic data for scenarioType='${SCENARIO_TYPE}'...`);

  const snap = await db.collection('evaluationReports').where('scenarioType', '==', SCENARIO_TYPE).get();
  const docs = snap.docs;
  const BATCH_SIZE = 400;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    docs.slice(i, i + BATCH_SIZE).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  console.log(`   Deleted ${docs.length} synthetic evaluationReports.`);

  for (let i = 0; i < NUM_USERS; i++) {
    await db.collection('users').doc(syntheticUserId(i)).delete().catch(() => {});
  }
  console.log(`   Deleted ${NUM_USERS} synthetic user docs.`);

  await db.collection('evaluationModel').doc(SCENARIO_TYPE).delete().catch(() => {});
  console.log(`   Deleted evaluationModel/${SCENARIO_TYPE} state doc.`);
  console.log('✨ Cleanup complete.');
}

async function seed({ count, mean, stdev }) {
  console.log(`🌱 Seeding ${count} synthetic evaluationReports (mean=${mean}, stdev=${stdev}) for scenarioType='${SCENARIO_TYPE}'...`);

  // Seed synthetic users with a skillHistory window so Loop B personalization
  // (rolling mean, cold-start branching) is exercisable too.
  for (let i = 0; i < NUM_USERS; i++) {
    const skillHistory = {};
    for (const dim of DIMENSIONS) {
      const window = Array.from({ length: 5 }, () => randomScore(mean, stdev));
      skillHistory[dim] = { window, updatedAt: Date.now() };
    }
    await db.collection('users').doc(syntheticUserId(i)).set(
      {
        uid: syntheticUserId(i),
        name: `Synthetic User ${i}`,
        email: `synthetic${i}@test.local`,
        synthetic: true,
        skillHistory,
      },
      { merge: true }
    );
  }
  console.log(`   Seeded ${NUM_USERS} synthetic user docs with skillHistory windows.`);

  const BATCH_SIZE = 400;
  let written = 0;
  for (let i = 0; i < count; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunkSize = Math.min(BATCH_SIZE, count - i);
    for (let j = 0; j < chunkSize; j++) {
      const idx = i + j;
      const scores = {};
      for (const dim of DIMENSIONS) scores[dim] = randomScore(mean, stdev);
      const ref = db.collection('evaluationReports').doc(`synthetic_${idx}`);
      batch.set(ref, {
        sessionId: `synthetic_${idx}`,
        userId: syntheticUserId(idx % NUM_USERS),
        scenarioType: SCENARIO_TYPE,
        generatedAt: FieldValue.serverTimestamp(),
        scores,
        fillerWordCount: 0,
        fillerWords: [],
        strengths: ['Synthetic strength A', 'Synthetic strength B'],
        improvements: ['Synthetic improvement A', 'Synthetic improvement B'],
        recommendedNextType: SCENARIO_TYPE,
        rawTranscript: '[synthetic]',
      });
    }
    await batch.commit();
    written += chunkSize;
    console.log(`   Wrote ${written}/${count}...`);
  }

  // ~inverse-normal CDF(0.6) ≈ 0.2533 stdevs above the mean — a quick sanity target.
  const expectedP60 = mean + stdev * 0.2533;
  console.log(`✨ Seed complete. Expected θ (60th percentile, roughly) ≈ ${expectedP60.toFixed(1)} for a normal(${mean}, ${stdev}) distribution.`);
  console.log(`   Next: POST /admin/evaluation-model/retrain, then`);
  console.log(`   GET /admin/evaluation-model/state?scenarioType=${SCENARIO_TYPE} to compare.`);
}

async function main() {
  const opts = parseArgs();
  if (opts.cleanup) {
    await cleanup();
  } else {
    await seed(opts);
  }
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Script failed:', err);
  process.exit(1);
});
