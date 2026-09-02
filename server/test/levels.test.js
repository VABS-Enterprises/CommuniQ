const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const levelsStore = require('../src/data/levelsStore');

const ROOT_SOURCE = path.join(__dirname, '..', '..', 'communiq_levels_1_20.json');

const ANSWER_KEY_FIELDS = [
  'correct_option',
  'incorrect_options',
  'correct_feedback',
  'incorrect_feedback',
];

test('the runtime copy matches the authored source', () => {
  // These two files drifting apart is exactly the failure this suite exists
  // to catch: the client would render options from one and be graded against
  // the other.
  assert.ok(fs.existsSync(ROOT_SOURCE), 'authored curriculum is missing');
  assert.strictEqual(
    fs.readFileSync(levelsStore.LEVELS_PATH, 'utf8'),
    fs.readFileSync(ROOT_SOURCE, 'utf8'),
    'run `npm run levels:sync`'
  );
});

test('every level is well formed', () => {
  const levels = levelsStore.getLevels();
  assert.ok(levels.length > 0, 'no levels loaded');

  const ids = new Set();
  for (const level of levels) {
    assert.ok(!ids.has(level.id), `duplicate level id ${level.id}`);
    ids.add(level.id);

    for (const field of ['title', 'scenario', 'emoji', 'skill', 'difficulty', 'goal']) {
      assert.ok(level[field], `level ${level.id} is missing ${field}`);
    }
    assert.ok(level.teaching && level.teaching.idea, `level ${level.id} has no teaching idea`);
    assert.ok(
      Array.isArray(level.teaching.points) && level.teaching.points.length > 0,
      `level ${level.id} has no teaching points`
    );
    assert.ok(level.response && level.response.prompt, `level ${level.id} has no response prompt`);

    assert.ok(Array.isArray(level.mcqs) && level.mcqs.length > 0, `level ${level.id} has no mcqs`);

    // Steps must be 1..n and contiguous — the client resumes a level by
    // looking up the server's step numbers, so gaps would strand a step.
    const steps = level.mcqs.map((m) => m.step);
    assert.deepStrictEqual(
      steps,
      steps.map((_, i) => i + 1),
      `level ${level.id} steps are not 1..n: ${steps}`
    );

    for (const mcq of level.mcqs) {
      assert.ok(mcq.question, `level ${level.id} step ${mcq.step} has no question`);
      assert.ok(mcq.correct_option, `level ${level.id} step ${mcq.step} has no answer`);
      assert.strictEqual(
        mcq.incorrect_options.length,
        3,
        `level ${level.id} step ${mcq.step} should have 3 distractors`
      );

      const all = [mcq.correct_option, ...mcq.incorrect_options];
      assert.strictEqual(
        new Set(all).size,
        all.length,
        `level ${level.id} step ${mcq.step} repeats an option — it would be ambiguous to grade`
      );
    }
  }
});

test('every level sits inside its declared journey', () => {
  const journeys = levelsStore.getJourneys();
  assert.ok(journeys.length > 0, 'no journeys declared');

  const byId = new Map(journeys.map((j) => [j.id, j]));
  assert.strictEqual(byId.size, journeys.length, 'duplicate journey id');

  for (const level of levelsStore.getLevels()) {
    const journey = byId.get(level.journey_id);
    assert.ok(journey, `level ${level.id} references unknown journey ${level.journey_id}`);
    assert.ok(
      level.id >= journey.start_level && level.id <= journey.end_level,
      `level ${level.id} is outside journey ${journey.id} (${journey.start_level}-${journey.end_level})`
    );
    assert.strictEqual(
      level.journey_title,
      journey.title,
      `level ${level.id} journey_title disagrees with journey ${journey.id}`
    );
  }
});

test('GET /levels leaks no part of the answer key', () => {
  const payload = levelsStore.getSanitizedPayload();
  const serialised = JSON.stringify(payload);

  for (const field of ANSWER_KEY_FIELDS) {
    assert.ok(
      !serialised.includes(field),
      `the client payload still contains "${field}"`
    );
  }

  // Feedback strings have to go too: holding both outcomes reveals the answer
  // as surely as holding the key.
  for (const level of levelsStore.getLevels()) {
    for (const mcq of level.mcqs) {
      assert.ok(
        !serialised.includes(mcq.correct_feedback),
        `level ${level.id} step ${mcq.step} leaks its correct feedback`
      );
    }
  }
});

test('sanitised options keep the full choice set, including the answer', () => {
  const payload = levelsStore.getSanitizedPayload();

  for (const level of levelsStore.getLevels()) {
    const sanitised = payload.levels.find((l) => l.id === level.id);
    assert.ok(sanitised, `level ${level.id} missing from payload`);
    assert.strictEqual(sanitised.mcq_count, level.mcqs.length);

    for (const mcq of level.mcqs) {
      const step = sanitised.mcqs.find((m) => m.step === mcq.step);
      assert.ok(step, `level ${level.id} step ${mcq.step} missing from payload`);
      assert.strictEqual(step.options.length, 4);
      assert.ok(
        step.options.includes(mcq.correct_option),
        `level ${level.id} step ${mcq.step} dropped the correct answer — it would be unanswerable`
      );
      assert.deepStrictEqual(
        [...step.options].sort(),
        [mcq.correct_option, ...mcq.incorrect_options].sort(),
        `level ${level.id} step ${mcq.step} altered the option set`
      );
    }
  }
});

test('option order is stable across re-fetches', () => {
  // A client that re-fetches mid-level must not see the options jump around,
  // so the seeded shuffle has to produce the same order every time.
  for (const level of levelsStore.getLevels()) {
    assert.deepStrictEqual(
      levelsStore.sanitizeLevel(level).mcqs,
      levelsStore.sanitizeLevel(level).mcqs,
      `level ${level.id} shuffles differently between calls`
    );
  }
});

test('the correct answer is not clustered in one position', () => {
  const payload = levelsStore.getSanitizedPayload();
  const positions = [0, 0, 0, 0];
  let total = 0;

  for (const level of levelsStore.getLevels()) {
    const sanitised = payload.levels.find((l) => l.id === level.id);
    for (const mcq of level.mcqs) {
      const step = sanitised.mcqs.find((m) => m.step === mcq.step);
      positions[step.options.indexOf(mcq.correct_option)] += 1;
      total += 1;
    }
  }

  // With a fair shuffle each slot holds ~25%. Anything past 40% would mean
  // "always pick C" beats reading the question.
  for (let i = 0; i < positions.length; i += 1) {
    const share = positions[i] / total;
    assert.ok(
      share < 0.4,
      `position ${i} holds ${(share * 100).toFixed(1)}% of answers — too predictable`
    );
  }
});

test('findStep resolves by the server step number', () => {
  const level = levelsStore.findLevel(1);
  assert.strictEqual(levelsStore.findStep(level, 1).step, 1);
  assert.strictEqual(levelsStore.findStep(level, 999), null);
  assert.strictEqual(levelsStore.findLevel(9999), null);
});
