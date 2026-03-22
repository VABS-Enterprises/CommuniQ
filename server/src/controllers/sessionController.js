const { v4: uuidv4 } = require('uuid');
const { FieldValue } = require('firebase-admin/firestore');
const { createTurnDoc } = require('../models/sessionModel');
const {
  createSession,
  getSessionById,
  getScenarioById,
  appendTurnsToSession,
  completeSession,
  abandonSession: abandonSessionInDb,
  writeEvaluationReport,
  getEvaluationReport,
  getUserById,
  updateUser,
  countCompletedSessions,
  getUserSessions,
} = require('../services/firestoreService');
const { sendTurnToFastApi, evaluateSession } = require('../services/fastApiService');
const { computeXpAward, computeLevel, computeStreak, computeNewBadges } = require('../services/xpService');

// POST /sessions/start
async function startSession(req, res) {
  const { scenarioId } = req.body;
  const userId = req.uid;

  if (!scenarioId) {
    return res.status(400).json({ error: 'scenarioId is required' });
  }

  try {
    const scenario = await getScenarioById(scenarioId);
    if (!scenario) return res.status(404).json({ error: 'Scenario not found' });

    const user = await getUserById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (user.level < scenario.requiredLevel) {
      return res.status(403).json({ error: `Scenario requires level ${scenario.requiredLevel}` });
    }

    const sessionId = uuidv4();
    await createSession(sessionId, { userId, scenarioId });
    return res.status(201).json({ sessionId });
  } catch (err) {
    console.error('startSession error:', err.message);
    return res.status(500).json({ error: 'Could not start session' });
  }
}

// POST /sessions/turn
async function processTurn(req, res) {
  const { sessionId, conversationHistory } = req.body;
  const userId = req.uid;
  const audioFile = req.file;

  if (!sessionId || !audioFile) {
    return res.status(400).json({ error: 'sessionId and audioFile are required' });
  }

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    if (session.status !== 'in_progress') {
      return res.status(400).json({ error: 'Session is not in progress' });
    }

    const scenario = await getScenarioById(session.scenarioId);
    const history = conversationHistory ? JSON.parse(conversationHistory) : [];

    const fastApiResult = await sendTurnToFastApi(
      audioFile.buffer,
      audioFile.originalname,
      sessionId,
      history,
      scenario.systemPrompt
    );

    const { userTranscript, aiReply, aiAudioBase64 } = fastApiResult;

    await appendTurnsToSession(
      sessionId,
      createTurnDoc('user', userTranscript),
      createTurnDoc('ai', aiReply)
    );

    return res.status(200).json({ userTranscript, aiReply, aiAudioBase64 });
  } catch (err) {
    console.error('processTurn error:', err.message);
    return res.status(500).json({ error: 'Failed to process turn' });
  }
}

// POST /sessions/end
async function endSession(req, res) {
  const { sessionId } = req.body;
  const userId = req.uid;

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId is required' });
  }

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    if (session.status !== 'in_progress') {
      return res.status(400).json({ error: 'Session is not in progress' });
    }

    const scenario = await getScenarioById(session.scenarioId);
    const startedAt = session.startedAt?.toDate ? session.startedAt.toDate() : new Date(session.startedAt);
    const durationSeconds = Math.round((Date.now() - startedAt.getTime()) / 1000);

    // Build full transcript string
    const rawTranscript = (session.turns || [])
      .map((t) => `${t.role === 'user' ? 'User' : 'AI'}: ${t.transcript}`)
      .join('\n');

    // Mark session complete
    await completeSession(sessionId, durationSeconds);

    // Call FastAPI for evaluation
    const evaluation = await evaluateSession(sessionId, rawTranscript, scenario.type);

    // Write evaluation report
    const report = await writeEvaluationReport(sessionId, {
      userId,
      scores: evaluation.scores,
      fillerWordCount: evaluation.fillerWordCount,
      fillerWords: evaluation.fillerWords,
      strengths: evaluation.strengths,
      improvements: evaluation.improvements,
      recommendedNextScenarioId: evaluation.recommendedNextScenarioId,
      rawTranscript,
    });

    // XP + gamification
    const user = await getUserById(userId);
    const xpAwarded = computeXpAward(evaluation.scores);
    const newXp = (user.xp || 0) + xpAwarded;
    const oldLevel = user.level || 1;
    const newLevel = computeLevel(newXp);
    const leveledUp = newLevel > oldLevel;
    const newStreak = computeStreak(user.lastActiveDate, user.streak || 0);
    const completedCount = await countCompletedSessions(userId);
    const newBadges = computeNewBadges({
      existingBadges: user.badges || [],
      completedSessionCount: completedCount,
      newStreak,
      scores: evaluation.scores,
      leveledUp,
    });

    const userUpdates = {
      xp: newXp,
      level: newLevel,
      streak: newStreak,
      lastActiveDate: FieldValue.serverTimestamp(),
    };
    if (newBadges.length > 0) {
      userUpdates.badges = FieldValue.arrayUnion(...newBadges);
    }
    await updateUser(userId, userUpdates);

    return res.status(200).json({ report, xpAwarded, newLevel, leveledUp, newBadges, newStreak });
  } catch (err) {
    console.error('endSession error:', err.message);
    return res.status(500).json({ error: 'Failed to end session' });
  }
}

// GET /sessions/:sessionId/report
async function getReport(req, res) {
  const { sessionId } = req.params;
  const userId = req.uid;

  try {
    const report = await getEvaluationReport(sessionId);
    if (!report) return res.status(404).json({ error: 'Report not found' });
    if (report.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    return res.status(200).json({ report });
  } catch (err) {
    console.error('getReport error:', err.message);
    return res.status(500).json({ error: 'Could not fetch report' });
  }
}

// POST /sessions/:sessionId/abandon
async function abandonSession(req, res) {
  const { sessionId } = req.params;
  const userId = req.uid;

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    if (session.status !== 'in_progress') {
      return res.status(400).json({ error: 'Only in-progress sessions can be abandoned' });
    }

    await abandonSessionInDb(sessionId);
    return res.status(200).json({ message: 'Session abandoned' });
  } catch (err) {
    console.error('abandonSession error:', err.message);
    return res.status(500).json({ error: 'Could not abandon session' });
  }
}

// GET /sessions/history
async function getSessionHistory(req, res) {
  const userId = req.uid;
  const limit = Math.min(parseInt(req.query.limit) || 20, 50);

  try {
    const sessions = await getUserSessions(userId, limit);
    return res.status(200).json({ sessions });
  } catch (err) {
    console.error('getSessionHistory error:', err.message);
    return res.status(500).json({ error: 'Could not fetch session history' });
  }
}

// GET /sessions/:sessionId
async function getSession(req, res) {
  const { sessionId } = req.params;
  const userId = req.uid;

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    return res.status(200).json({ session });
  } catch (err) {
    console.error('getSession error:', err.message);
    return res.status(500).json({ error: 'Could not fetch session' });
  }
}

module.exports = { startSession, processTurn, endSession, getReport, abandonSession, getSessionHistory, getSession };
