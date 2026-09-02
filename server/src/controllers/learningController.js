const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const levelsStore = require('../data/levelsStore');

/*
 * Server-authoritative grading and progress for the learning module.
 *
 * The answer key never leaves this process. The Flutter client receives
 * questions and options from GET /levels with the correct option stripped
 * (see data/levelsStore.js) and submits answers here for grading, so a
 * decompiled APK reveals nothing.
 *
 * Every coin in the system is awarded here, exactly once per source:
 *   - MCQ step:        10 / 7 / 4 / 1 by attempt number
 *   - Written response: 15 / 10 / 6 / 3 by AI score band
 *   - Level completion: a flat 20 bonus
 *
 * The written-response coins used to be added on the client only and never
 * persisted, which meant the server's coin total could never reach the value
 * the UI had already shown the user. They are now awarded in completeLevel.
 */

const MAX_SELECTED_OPTION_LENGTH = 2000;

/** Revealing the answer costs the user their remaining coins on this step. */
const REVEAL_AFTER_ATTEMPTS = 2;

const LEVEL_COMPLETE_BONUS = 20;

function coinsForAttempt(attemptNumber) {
  return Math.max(1, 10 - 3 * (attemptNumber - 1));
}

function coinsForResponseScore(score) {
  if (score > 75) return 15;
  if (score > 50) return 10;
  if (score > 30) return 6;
  return 3;
}

function readProgress(data) {
  const lp = (data && data.learningProgress) || {};
  return {
    coins: typeof lp.coins === 'number' ? lp.coins : 0,
    completedLevelIds: Array.isArray(lp.completedLevelIds) ? lp.completedLevelIds : [],
    levels: lp.levels || {},
    attempts: lp.attempts || {},
    levelCoins: lp.levelCoins || {},
    responses: lp.responses || {},
  };
}

// GET /learning/progress
async function getProgress(req, res) {
  try {
    const snap = await db.collection('users').doc(req.uid).get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    const lp = readProgress(snap.data());

    // Total steps per level, so the client can render "3 of 4" without
    // holding the curriculum itself.
    const stepTotals = {};
    for (const level of levelsStore.getLevels()) {
      stepTotals[level.id] = Array.isArray(level.mcqs) ? level.mcqs.length : 0;
    }

    return res.status(200).json({
      coins: lp.coins,
      completedLevelIds: lp.completedLevelIds,
      levelProgress: lp.levels,
      levelCoins: lp.levelCoins,
      responses: lp.responses,
      stepTotals,
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

  const level = levelsStore.findLevel(levelId);
  if (!level) {
    return res.status(404).json({ error: `Level ${levelId} not found` });
  }
  const mcq = levelsStore.findStep(level, step);
  if (!mcq) {
    return res.status(404).json({ error: `Step ${step} not found in level ${levelId}` });
  }

  const isCorrectSubmission = selectedOption === mcq.correct_option;
  const levelKey = String(levelId);
  const stepKey = String(step);
  const attemptKey = `${levelId}_${step}`;
  const totalSteps = Array.isArray(level.mcqs) ? level.mcqs.length : 0;

  const userRef = db.collection('users').doc(req.uid);

  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        return { notFound: true };
      }
      const lp = readProgress(snap.data());
      const levelSteps = lp.levels[levelKey] || {};
      const alreadyCorrect = levelSteps[stepKey] === true;

      // How many steps in this level are solved, for the live progress bar.
      const solvedAfter = (extra) =>
        Object.values({ ...levelSteps, ...extra }).filter((v) => v === true).length;

      if (alreadyCorrect) {
        // Idempotent — no double-dipping on coins for an already-solved step.
        return {
          correct: true,
          coinsAwarded: 0,
          totalCoins: lp.coins,
          attemptNumber: lp.attempts[attemptKey] || 1,
          feedback: mcq.correct_feedback || 'Correct!',
          correctOption: mcq.correct_option,
          stepsSolved: solvedAfter({}),
          totalSteps,
        };
      }

      const attemptNumber = (lp.attempts[attemptKey] || 0) + 1;

      if (isCorrectSubmission) {
        const coinsAwarded = coinsForAttempt(attemptNumber);
        const totalCoins = lp.coins + coinsAwarded;
        const levelTotal = (lp.levelCoins[levelKey] || 0) + coinsAwarded;
        tx.set(
          userRef,
          {
            learningProgress: {
              coins: totalCoins,
              attempts: { [attemptKey]: attemptNumber },
              levels: { [levelKey]: { [stepKey]: true } },
              levelCoins: { [levelKey]: levelTotal },
            },
          },
          { merge: true }
        );
        return {
          correct: true,
          coinsAwarded,
          totalCoins,
          attemptNumber,
          feedback: mcq.correct_feedback || 'Correct!',
          correctOption: mcq.correct_option,
          stepsSolved: solvedAfter({ [stepKey]: true }),
          totalSteps,
        };
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

      // After two misses the step stops being a test and starts being a
      // lesson: send the correct option so the client can show what the
      // right answer was and why. The user has already lost most of the
      // coins for this step, so this is not a shortcut worth exploiting —
      // and leaving them guessing blind teaches nothing.
      const reveal = attemptNumber >= REVEAL_AFTER_ATTEMPTS;

      return {
        correct: false,
        coinsAwarded: 0,
        totalCoins: lp.coins,
        attemptNumber,
        feedback: mcq.incorrect_feedback || 'Not quite — try again.',
        ...(reveal ? { correctOption: mcq.correct_option, revealed: true } : {}),
        stepsSolved: solvedAfter({}),
        totalSteps,
      };
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

/*
 * POST /learning/levels/:levelId/complete
 * Body: { responseScore?: number }
 *
 * Verifies every MCQ step was answered correctly, then awards the written
 * response coins and the completion bonus. Both are awarded once — replaying
 * a finished level re-shows the content but pays nothing.
 */
async function completeLevel(req, res) {
  const levelId = Number(req.params.levelId);
  if (!Number.isInteger(levelId) || levelId <= 0) {
    return res.status(400).json({ error: 'levelId must be a positive integer' });
  }

  const level = levelsStore.findLevel(levelId);
  if (!level) {
    return res.status(404).json({ error: `Level ${levelId} not found` });
  }

  const rawScore = req.body ? req.body.responseScore : undefined;
  const responseScore =
    typeof rawScore === 'number' && Number.isFinite(rawScore)
      ? Math.max(0, Math.min(100, Math.round(rawScore)))
      : null;

  const requiredSteps = Array.isArray(level.mcqs) ? level.mcqs.map((m) => m.step) : [];
  const levelKey = String(levelId);
  const userRef = db.collection('users').doc(req.uid);

  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) return { notFound: true };

      const lp = readProgress(snap.data());
      const levelSteps = lp.levels[levelKey] || {};

      const missingSteps = requiredSteps.filter((s) => levelSteps[String(s)] !== true);
      if (missingSteps.length > 0) return { missingSteps };

      const alreadyComplete = lp.completedLevelIds.includes(levelId);
      const priorResponse = lp.responses[levelKey];

      let earned = 0;
      const payload = { completedLevelIds: FieldValue.arrayUnion(levelId) };

      if (responseScore !== null && !priorResponse) {
        const responseCoins = coinsForResponseScore(responseScore);
        earned += responseCoins;
        payload.responses = {
          [levelKey]: { score: responseScore, coins: responseCoins },
        };
      }
      if (!alreadyComplete) {
        earned += LEVEL_COMPLETE_BONUS;
      }

      const totalCoins = lp.coins + earned;
      if (earned > 0) {
        payload.coins = totalCoins;
        payload.levelCoins = { [levelKey]: (lp.levelCoins[levelKey] || 0) + earned };
      }

      tx.set(userRef, { learningProgress: payload }, { merge: true });

      const completedLevelIds = alreadyComplete
        ? lp.completedLevelIds
        : [...lp.completedLevelIds, levelId];

      return {
        completedLevelIds,
        coinsAwarded: earned,
        totalCoins,
        levelCoins: (lp.levelCoins[levelKey] || 0) + earned,
        alreadyComplete,
      };
    });

    if (result.notFound) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (result.missingSteps) {
      return res.status(400).json({
        error: 'All MCQ steps for this level must be answered correctly before completing it',
        missingSteps: result.missingSteps,
      });
    }
    return res.status(200).json(result);
  } catch (err) {
    console.error('completeLevel error:', err.message);
    return res.status(500).json({ error: 'Could not complete level' });
  }
}

module.exports = { getProgress, submitAnswer, completeLevel };
