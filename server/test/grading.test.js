/*
 * End-to-end exercise of the learning controller against an in-memory
 * Firestore stub.
 *
 * Covers the parts of the coin economy that are easy to get subtly wrong and
 * impossible to notice from the UI: award decay by attempt, idempotency on a
 * replayed step, the completion gate, and — the one that actually shipped
 * broken — whether a level stays completable after the user takes a revealed
 * answer.
 */
const test = require('node:test');
const path = require('path');
const assert = require('node:assert');

const SERVER = path.join(__dirname, '..');

// ── In-memory Firestore ──────────────────────────────────────────────────────
const FieldValue = {
  arrayUnion: (...vals) => ({ __arrayUnion: vals }),
};

let store = {};

function deepMerge(target, patch) {
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === 'object' && v.__arrayUnion) {
      const existing = Array.isArray(target[k]) ? target[k] : [];
      target[k] = [...new Set([...existing, ...v.__arrayUnion])];
    } else if (v && typeof v === 'object' && !Array.isArray(v)) {
      target[k] = deepMerge(target[k] && typeof target[k] === 'object' ? { ...target[k] } : {}, v);
    } else {
      target[k] = v;
    }
  }
  return target;
}

function docRef(uid) {
  return {
    uid,
    async get() {
      return { exists: store[uid] !== undefined, data: () => store[uid] };
    },
    async set(patch, opts) {
      if (!opts || !opts.merge) { store[uid] = patch; return; }
      store[uid] = deepMerge(store[uid] || {}, patch);
    },
  };
}

const db = {
  collection: () => ({ doc: docRef }),
  async runTransaction(fn) {
    const tx = {
      get: (ref) => ref.get(),
      set: (ref, patch, opts) => { ref.set(patch, opts); },
    };
    return fn(tx);
  },
};

// Inject the stub before the controller loads.
require.cache[require.resolve(path.join(SERVER, 'src/config/firebase.js'))] = {
  id: 'firebase-stub', filename: 'firebase-stub', loaded: true, exports: { db },
};
require.cache[require.resolve('firebase-admin/firestore')] = {
  id: 'fs-stub', filename: 'fs-stub', loaded: true, exports: { FieldValue },
};

const controller = require(path.join(SERVER, 'src/controllers/learningController.js'));
const levelsStore = require(path.join(SERVER, 'src/data/levelsStore.js'));

// ── Test harness ─────────────────────────────────────────────────────────────
function res() {
  const r = {
    statusCode: null, body: null,
    status(c) { r.statusCode = c; return r; },
    json(b) { r.body = b; return r; },
  };
  return r;
}

const UID = 'user-1';
const answer = async (levelId, step, selectedOption) => {
  const r = res();
  await controller.submitAnswer({ uid: UID, body: { levelId, step, selectedOption } }, r);
  return r;
};
const complete = async (levelId, responseScore) => {
  const r = res();
  await controller.completeLevel({ uid: UID, params: { levelId: String(levelId) }, body: { responseScore } }, r);
  return r;
};
const progress = async () => {
  const r = res();
  await controller.getProgress({ uid: UID }, r);
  return r;
};

function reset() { store = { [UID]: { learningProgress: {} } }; }

const level = levelsStore.findLevel(1);
const s1 = level.mcqs[0];
const s2 = level.mcqs[1];
const check = (name, fn) => test(name, fn);

check('first-try correct pays 10 coins', async () => {
  reset();
  const r = await answer(1, 1, s1.correct_option);
  assert.strictEqual(r.statusCode, 200);
  assert.strictEqual(r.body.correct, true);
  assert.strictEqual(r.body.coinsAwarded, 10);
  assert.strictEqual(r.body.totalCoins, 10);
  assert.strictEqual(r.body.stepsSolved, 1);
  assert.strictEqual(r.body.totalSteps, level.mcqs.length);
});

check('a wrong answer pays nothing and withholds the answer', async () => {
  reset();
  const r = await answer(1, 1, s1.incorrect_options[0]);
  assert.strictEqual(r.body.correct, false);
  assert.strictEqual(r.body.coinsAwarded, 0);
  assert.strictEqual(r.body.totalCoins, 0);
  assert.strictEqual(r.body.correctOption, undefined, 'must not leak on first miss');
  assert.ok(r.body.feedback);
});

check('a second miss reveals the answer so the step can teach', async () => {
  reset();
  await answer(1, 1, s1.incorrect_options[0]);
  const r = await answer(1, 1, s1.incorrect_options[1]);
  assert.strictEqual(r.body.correct, false);
  assert.strictEqual(r.body.revealed, true);
  assert.strictEqual(r.body.correctOption, s1.correct_option);
});

check('coins decay 10 / 7 / 4 / 1 by attempt', async () => {
  const expected = [10, 7, 4, 1];
  for (let attempt = 0; attempt < 4; attempt += 1) {
    reset();
    for (let i = 0; i < attempt; i += 1) {
      await answer(1, 1, s1.incorrect_options[i % 3]);
    }
    const r = await answer(1, 1, s1.correct_option);
    assert.strictEqual(r.body.correct, true);
    assert.strictEqual(r.body.coinsAwarded, expected[attempt],
      `attempt ${attempt + 1} should pay ${expected[attempt]}`);
  }
});

check('re-answering a solved step pays nothing (idempotent)', async () => {
  reset();
  await answer(1, 1, s1.correct_option);
  const r = await answer(1, 1, s1.correct_option);
  assert.strictEqual(r.body.coinsAwarded, 0);
  assert.strictEqual(r.body.totalCoins, 10, 'must not double-pay');
});

check('completing with steps outstanding is rejected', async () => {
  reset();
  await answer(1, 1, s1.correct_option);
  const r = await complete(1, 80);
  assert.strictEqual(r.statusCode, 400);
  assert.ok(r.body.missingSteps.length > 0);
});

check('completing pays the response coins and the bonus, once', async () => {
  reset();
  for (const mcq of level.mcqs) await answer(1, mcq.step, mcq.correct_option);
  const mcqCoins = 10 * level.mcqs.length;

  const first = await complete(1, 82); // score > 75 -> 15 coins, + 20 bonus
  assert.strictEqual(first.statusCode, 200);
  assert.strictEqual(first.body.coinsAwarded, 35);
  assert.strictEqual(first.body.totalCoins, mcqCoins + 35);
  assert.deepStrictEqual(first.body.completedLevelIds, [1]);

  const second = await complete(1, 82);
  assert.strictEqual(second.body.coinsAwarded, 0, 'replay must pay nothing');
  assert.strictEqual(second.body.totalCoins, mcqCoins + 35);
  assert.strictEqual(second.body.alreadyComplete, true);
});

check('response coins band by score', async () => {
  for (const [score, coins] of [[90, 15], [60, 10], [40, 6], [10, 3]]) {
    reset();
    for (const mcq of level.mcqs) await answer(1, mcq.step, mcq.correct_option);
    const r = await complete(1, score);
    assert.strictEqual(r.body.coinsAwarded, coins + 20, `score ${score}`);
  }
});

check('progress reports what the client needs to resume', async () => {
  reset();
  await answer(1, 1, s1.correct_option);
  await answer(1, 2, s2.correct_option);
  const r = await progress();
  assert.strictEqual(r.statusCode, 200);
  assert.strictEqual(r.body.coins, 20);
  assert.strictEqual(r.body.levelProgress['1']['1'], true);
  assert.strictEqual(r.body.levelProgress['1']['2'], true);
  assert.strictEqual(r.body.levelCoins['1'], 20);
  assert.strictEqual(r.body.stepTotals['1'], level.mcqs.length);
});

check('a full 20-level playthrough is reachable and bounded', async () => {
  reset();
  let expected = 0;
  for (const lvl of levelsStore.getLevels()) {
    for (const mcq of lvl.mcqs) {
      const r = await answer(lvl.id, mcq.step, mcq.correct_option);
      assert.strictEqual(r.body.correct, true, `level ${lvl.id} step ${mcq.step}`);
      expected += 10;
    }
    const c = await complete(lvl.id, 90);
    assert.strictEqual(c.statusCode, 200, `level ${lvl.id} completion`);
    expected += 35;
  }
  const p = await progress();
  assert.strictEqual(p.body.completedLevelIds.length, 20, 'all 20 completable');
  assert.strictEqual(p.body.coins, expected);
  console.log(`     perfect run total: ${expected} coins across 20 levels`);
});

check('a level is still completable after using the reveal', async () => {
  reset();
  // Miss twice on every step, take the revealed answer, then finish. This is
  // the path that would strand a user if the client treated "revealed" as
  // done without recording it: completeLevel demands every step be correct.
  for (const mcq of level.mcqs) {
    await answer(1, mcq.step, mcq.incorrect_options[0]);
    const second = await answer(1, mcq.step, mcq.incorrect_options[1]);
    assert.strictEqual(second.body.revealed, true);
    const ack = await answer(1, mcq.step, second.body.correctOption);
    assert.strictEqual(ack.body.correct, true);
    assert.strictEqual(ack.body.coinsAwarded, 4, 'third attempt pays 4');
  }
  const c = await complete(1, 70);
  assert.strictEqual(c.statusCode, 200, 'reveal path must still complete');
  const p = await progress();
  assert.ok(p.body.completedLevelIds.includes(1));
});

check('bad input is rejected', async () => {
  reset();
  const cases = [
    [{ levelId: 0, step: 1, selectedOption: 'x' }],
    [{ levelId: 1, step: 0, selectedOption: 'x' }],
    [{ levelId: 1, step: 1, selectedOption: '' }],
    [{ levelId: 1, step: 1, selectedOption: 'x'.repeat(2001) }],
  ];
  for (const [body] of cases) {
    const r = res();
    await controller.submitAnswer({ uid: UID, body }, r);
    assert.strictEqual(r.statusCode, 400, JSON.stringify(body).slice(0, 60));
  }
  const missing = await answer(9999, 1, 'x');
  assert.strictEqual(missing.statusCode, 404);
});
