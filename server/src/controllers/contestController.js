const { v4: uuidv4 } = require('uuid');
const { FieldValue } = require('firebase-admin/firestore');
const { evaluateContestAnswer } = require('../services/fastApiService');
const {
  createContestAttempt,
  getUserContestAttempts,
  getContestLeaderboard,
  getUserById,
  updateUser,
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
    const user = await getUserById(userId);
    const name = user?.name || (req.email ? req.email.split('@')[0] : 'User');

    await createContestAttempt(attemptId, {
      userId,
      name,
      contestType,
      motion: motion || null,
      position: position || null,
      userAnswer: userAnswer.trim(),
      scores: evaluation.scores,
      overallScore: evaluation.overallScore,
      strengths: evaluation.strengths,
      improvements: evaluation.improvements,
      feedback: evaluation.feedback,
      xpAwarded,
    });

    await updateUser(userId, { xp: FieldValue.increment(xpAwarded) });

    return res.status(200).json({ attemptId, ...evaluation, xpAwarded });
  } catch (err) {
    console.error('submitContestAnswer error:', err.message);
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Contest evaluation failed' });
  }
}

// GET /contest/history
async function getContestHistory(req, res) {
  const userId = req.uid;
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 50);

  try {
    const attempts = await getUserContestAttempts(userId, limit);
    return res.status(200).json({ attempts });
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
