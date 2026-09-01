const fs = require('fs');
const path = require('path');
const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');

/*
 * Server-authoritative grading for the learning module's MCQ steps.
 *
 * The answer key (learningLevels.json) never leaves this process — the
 * Flutter client only ever sees questions/options via a future "get level"
 * endpoint (or ships its own copy without correct answers), and submits
 * answers here for grading. This closes the decompile-and-cheat loophole
 * where the full answer key + coin-awarding logic used to live client-side.
 *
 * Coin formula (unchanged from the old client-side logic, now enforced
 * server-side): max(1, 10 - 3 * (attemptNumber - 1)) coins per MCQ step,
 * awarded exactly once — the first time that step is answered correctly.
 */

const LEVELS_PATH = path.join(__dirname, '..', 'data', 'learningLevels.json');

let _levelsCache = null;
function loadLevels() {
  if (_levelsCache) return _levelsCache;
  const raw = fs.readFileSync(LEVELS_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  const levels = Array.isArray(parsed.levels) ? parsed.levels : [];
  _levelsCache = new Map(levels.map((lvl) => [lvl.id, lvl]));
  return _levelsCache;
}

function findLevel(levelId) {
  return loadLevels().get(levelId) || null;
}

function findStep(level, step) {
  if (!level || !Array.isArray(level.mcqs)) return null;
  return level.mcqs.find((m) => m.step === step) || null;
}

const MAX_SELECTED_OPTION_LENGTH = 2000;

// GET /learning/progress
async function getProgress(req, res) {
  try {
    const snap = await db.collection('users').doc(req.uid).get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    const lp = snap.data().learningProgress || {};
    return res.status(200).json({
      coins: typeof lp.coins === 'number' ? lp.coins : 0,
      completedLevelIds: Array.isArray(lp.completedLevelIds) ? lp.completedLevelIds : [],
      levelProgress: lp.levels || {},
    });
  } catch (err) {
    console.error('getProgress error:', err.message);
    return res.status(500).json({ error: 'Could not fetch learning progress' });
  }
}

// POST /learning/answer
async function submitAnswer(req, res) {
  const { levelId, step, selectedOption } = req.body || {};

  if (!Number.isInteger(levelId) || levelId <= 0) {
    return res.status(400).json({ error: 'levelId must be a positive integer' });
  }
  if (!Number.isInteger(step) || step <= 0) {
    return res.status(400).json({ error: 'step must be a positive integer' });
  }
  if (typeof selectedOption !== 'string' || selectedOption.trim().length === 0) {
    return res.status(400).json({ error: 'selectedOption is required' });
  }
  if (selectedOption.length > MAX_SELECTED_OPTION_LENGTH) {
    return res.status(400).json({ error: 'selectedOption is too long' });
  }

  const level = findLevel(levelId);
  if (!level) {
    return res.status(404).json({ error: `Level ${levelId} not found` });
  }
  const mcq = findStep(level, step);
  if (!mcq) {
    return res.status(404).json({ error: `Step ${step} not found in level ${levelId}` });
  }

  const isCorrectSubmission = selectedOption === mcq.correct_option;
  const levelKey = String(levelId);
  const stepKey = String(step);
  const attemptKey = `${levelId}_${step}`;

  const userRef = db.collection('users').doc(req.uid);

  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        return { notFound: true };
      }
      const lp = snap.data().learningProgress || {};
      const coins = typeof lp.coins === 'number' ? lp.coins : 0;
      const levels = lp.levels || {};
      const attempts = lp.attempts || {};

      const alreadyCorrect = levels[levelKey] && levels[levelKey][stepKey] === true;

      if (alreadyCorrect) {
        // Idempotent — no double-dipping on coins for an already-solved step.
        return {
          correct: true,
          coinsAwarded: 0,
          totalCoins: coins,
          attemptNumber: attempts[attemptKey] || 1,
        };
      }

      const attemptNumber = (attempts[attemptKey] || 0) + 1;

      if (isCorrectSubmission) {
        const coinsAwarded = Math.max(1, 10 - 3 * (attemptNumber - 1));
        const totalCoins = coins + coinsAwarded;
        tx.set(
          userRef,
          {
            learningProgress: {
              coins: totalCoins,
              attempts: { [attemptKey]: attemptNumber },
              levels: { [levelKey]: { [stepKey]: true } },
            },
          },
          { merge: true }
        );
        return { correct: true, coinsAwarded, totalCoins, attemptNumber };
      }

      tx.set(
        userRef,
        {
          learningProgress: {
            attempts: { [attemptKey]: attemptNumber },
          },
        },
        { merge: true }
      );
      return { correct: false, coinsAwarded: 0, totalCoins: coins, attemptNumber };
    });

    if (result.notFound) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.status(200).json(result);
  } catch (err) {
    console.error('submitAnswer error:', err.message);
    return res.status(500).json({ error: 'Could not record answer' });
  }
}

// POST /learning/levels/:levelId/complete
async function completeLevel(req, res) {
  const levelId = Number(req.params.levelId);
  if (!Number.isInteger(levelId) || levelId <= 0) {
    return res.status(400).json({ error: 'levelId must be a positive integer' });
  }

  const level = findLevel(levelId);
  if (!level) {
    return res.status(404).json({ error: `Level ${levelId} not found` });
  }
  const requiredSteps = Array.isArray(level.mcqs) ? level.mcqs.map((m) => m.step) : [];

  const userRef = db.collection('users').doc(req.uid);

  try {
    const snap = await userRef.get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    const lp = snap.data().learningProgress || {};
    const levelMap = (lp.levels && lp.levels[String(levelId)]) || {};

    const missingSteps = requiredSteps.filter((step) => levelMap[String(step)] !== true);
    if (missingSteps.length > 0) {
      return res.status(400).json({
        error: 'All MCQ steps for this level must be answered correctly before completing it',
        missingSteps,
      });
    }

    await userRef.set(
      {
        learningProgress: {
          completedLevelIds: FieldValue.arrayUnion(levelId),
        },
      },
      { merge: true }
    );

    const existing = Array.isArray(lp.completedLevelIds) ? lp.completedLevelIds : [];
    const completedLevelIds = existing.includes(levelId) ? existing : [...existing, levelId];

    return res.status(200).json({ completedLevelIds });
  } catch (err) {
    console.error('completeLevel error:', err.message);
    return res.status(500).json({ error: 'Could not complete level' });
  }
}

module.exports = { getProgress, submitAnswer, completeLevel };
