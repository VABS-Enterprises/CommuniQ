const { v4: uuidv4 } = require('uuid');
const { db } = require('../config/firebase');
const { evaluateContestAnswer } = require('../services/fastApiService');
const { createContestAttemptDoc } = require('../models/contestModel');
const { applyActivityInTx } = require('../services/progressService');
const {
  getUserContestAttempts,
  getContestLeaderboard,
  getUserById,
} = require('../services/firestoreService');

const CONTEST_TYPES = new Set(['debate', 'gd', 'extempore', 'quiz']);
const MIN_ANSWER_LENGTH = 10;
const MAX_ANSWER_LENGTH = 6000;

// XP banding mirrors xpService.computeXpAward, applied to the single contest
// overallScore rather than averaging multiple roleplay dimension scores.
function computeContestXp(overallScore) {
  if (overallScore >= 80) return 100;
  if (overallScore >= 60) return 70;
  if (overallScore >= 40) return 40;
  return 20;
}

// POST /contest/submit
// Body: { contestType, motion?, position?, userAnswer }
// This is the endpoint that finally wires up ai-server's fully-built
// /evaluate/contest evaluator — it had a working client function
// (fastApiService.evaluateContestAnswer) but no Node route ever called it.
async function submitContestAnswer(req, res) {
  const userId = req.uid;
  const { contestType, motion, position, userAnswer } = req.body;

  if (!CONTEST_TYPES.has(contestType)) {
    return res.status(400).json({ error: `contestType must be one of: ${[...CONTEST_TYPES].join(', ')}` });
  }
  if (typeof userAnswer !== 'string' || userAnswer.trim().length < MIN_ANSWER_LENGTH) {
    return res.status(400).json({ error: `userAnswer must be at least ${MIN_ANSWER_LENGTH} characters` });
  }
  if (userAnswer.trim().length > MAX_ANSWER_LENGTH) {
    return res.status(400).json({ error: `userAnswer must be at most ${MAX_ANSWER_LENGTH} characters` });
  }

  const attemptId = uuidv4();

  try {
    const evaluation = await evaluateContestAnswer(
      attemptId,
      userAnswer.trim(),
      contestType,
      motion || '',
      position || ''
    );

    const xpAwarded = computeContestXp(evaluation.overallScore || 0);
    const overallScore = evaluation.overallScore || 0;
    const userRef = db.collection('users').doc(userId);
    const attemptRef = db.collection('contestAttempts').doc(attemptId);

    // The attempt, the XP/level/streak update and the per-user contest stats
    // commit together, so a failure can never leave a scored attempt without
    // its XP (or XP without an attempt) and invite a double-scored retry.
    const progress = await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        const err = new Error('User not found');
        err.statusCode = 404;
        throw err;
      }
      const user = snap.data();
      const name = user.name || (req.email ? req.email.split('@')[0] : 'User');

      tx.set(attemptRef, createContestAttemptDoc(attemptId, {
        userId,
        name,
        contestType,
        motion: motion || null,
        position: position || null,
        userAnswer: userAnswer.trim(),
        scores: evaluation.scores,
        overallScore,
        strengths: evaluation.strengths,
        improvements: evaluation.improvements,
        feedback: evaluation.feedback,
        xpAwarded,
      }));

      const stats = user.contestStats || {};
      const bestByType = stats.bestByType || {};
      return applyActivityInTx(tx, userRef, user, { xpAwarded }, {
        contestStats: {
          attempts: (stats.attempts || 0) + 1,
          bestScore: Math.max(stats.bestScore || 0, overallScore),
          bestByType: {
            ...bestByType,
            [contestType]: Math.max(bestByType[contestType] || 0, overallScore),
          },
        },
      });
    });

    return res.status(200).json({
      attemptId,
      ...evaluation,
      xpAwarded,
      newLevel: progress.newLevel,
      leveledUp: progress.leveledUp,
      newStreak: progress.newStreak,
      newBadges: progress.newBadges,
    });
  } catch (err) {
    console.error('submitContestAnswer error:', err.message);
    const status = err.statusCode || 500;
    return res.status(status).json({
      error: status >= 500 ? 'Contest evaluation failed — please try again' : err.message,
    });
  }
}

// GET /contest/history
async function getContestHistory(req, res) {
  const userId = req.uid;
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);

  try {
    const [attempts, user] = await Promise.all([
      getUserContestAttempts(userId, limit),
      getUserById(userId),
    ]);
    const stats = (user && user.contestStats) || {};
    return res.status(200).json({
      attempts,
      stats: {
        attempts: stats.attempts || 0,
        bestScore: stats.bestScore || 0,
        bestByType: stats.bestByType || {},
      },
    });
  } catch (err) {
    console.error('getContestHistory error:', err.message);
    return res.status(500).json({ error: 'Could not fetch contest history' });
  }
}

// GET /contest/leaderboard?contestType=debate&limit=50
async function getLeaderboard(req, res) {
  const { contestType } = req.query;
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);

  if (contestType && !CONTEST_TYPES.has(contestType)) {
    return res.status(400).json({ error: `contestType must be one of: ${[...CONTEST_TYPES].join(', ')}` });
  }

  try {
    const leaderboard = await getContestLeaderboard(contestType, limit);
    return res.status(200).json({ leaderboard });
  } catch (err) {
    console.error('getContestLeaderboard error:', err.message);
    return res.status(500).json({ error: 'Could not fetch contest leaderboard' });
  }
}

module.exports = { submitContestAnswer, getContestHistory, getLeaderboard };
