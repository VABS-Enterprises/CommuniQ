const fs = require('fs');
const path = require('path');

/*
 * Single source of truth for the learning curriculum.
 *
 * There used to be two copies of this data — `communiq_levels_1_20.json` at
 * the repo root (served by GET /levels) and `server/src/data/learningLevels.json`
 * (the answer key used for grading). Nothing kept them in sync, so a content
 * edit that landed in only one of them would show the user one set of options
 * while grading against another. Both routes now load through this module.
 *
 * The canonical runtime file lives under `server/`, because Render deploys the
 * Node service with `rootDir: server` — a path that escapes the service
 * directory is not something to depend on at runtime. The root file is the
 * authored source; `npm run levels:sync` copies it here.
 */

const LEVELS_PATH = path.join(__dirname, 'learningLevels.json');

let _cache = null;

function load() {
  if (_cache) return _cache;

  const raw = fs.readFileSync(LEVELS_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  const levels = Array.isArray(parsed.levels) ? parsed.levels : [];

  _cache = {
    meta: parsed,
    levels,
    byId: new Map(levels.map((lvl) => [lvl.id, lvl])),
    journeys: Array.isArray(parsed.journeys) ? parsed.journeys : [],
  };
  return _cache;
}

/** Every level, answer key included. Never send this to a client. */
function getLevels() {
  return load().levels;
}

function findLevel(levelId) {
  return load().byId.get(levelId) || null;
}

function findStep(level, step) {
  if (!level || !Array.isArray(level.mcqs)) return null;
  return level.mcqs.find((m) => m.step === step) || null;
}

function getJourneys() {
  return load().journeys;
}

/*
 * Deterministic option ordering.
 *
 * The correct answer must not be identifiable by its position, but the order
 * must also be stable — a client that re-fetches mid-level should not see the
 * options jump around. A seeded shuffle keyed on levelId+step gives both.
 */
function seededShuffle(items, seed) {
  const out = items.slice();
  // Mix the seed before use: consecutive small seeds (levelId*1000+step) leave
  // xorshift poorly diffused for the first few outputs, which skewed how often
  // the correct answer landed in position 0.
  let state = Math.imul(seed ^ 0x9e3779b9, 0x85ebca6b) >>> 0;
  state ^= state >>> 13;
  state = Math.imul(state, 0xc2b2ae35) >>> 0;
  state ^= state >>> 16;
  if (state === 0) state = 0x6d2b79f5;
  const next = () => {
    // xorshift32 — tiny, deterministic, and adequate for ordering options.
    state ^= state << 13; state >>>= 0;
    state ^= state >> 17;
    state ^= state << 5; state >>>= 0;
    return state;
  };
  for (let i = out.length - 1; i > 0; i--) {
    const j = next() % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/*
 * Strips the answer key out of a level before it goes over the wire.
 *
 * The client needs the question and its options to render the step; it must
 * not learn which option is correct, nor the per-outcome feedback (which would
 * leak the answer just as effectively). Grading happens in
 * learningController.submitAnswer, which returns the right feedback string.
 *
 * Everything else on the level — title, scenario, emoji, skill, goal and the
 * `teaching` block — is content the client is meant to render, so it passes
 * through untouched.
 */
function sanitizeLevel(level) {
  const mcqs = Array.isArray(level.mcqs) ? level.mcqs : [];
  return {
    ...level,
    mcq_count: mcqs.length,
    mcqs: mcqs.map((m) => ({
      step: m.step,
      question: m.question,
      options: seededShuffle(
        [m.correct_option, ...(m.incorrect_options || [])],
        (level.id * 1000) + (m.step || 1)
      ),
    })),
  };
}

let _sanitizedCache = null;

/** The full payload for GET /levels, with every answer key removed. */
function getSanitizedPayload() {
  if (_sanitizedCache) return _sanitizedCache;
  const { meta, levels } = load();
  _sanitizedCache = { ...meta, levels: levels.map(sanitizeLevel) };
  return _sanitizedCache;
}

module.exports = {
  LEVELS_PATH,
  getLevels,
  findLevel,
  findStep,
  getJourneys,
  getSanitizedPayload,
  sanitizeLevel,
};
