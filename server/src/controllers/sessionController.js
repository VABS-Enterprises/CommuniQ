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
  upsertGoogleUser,
  createUser,
} = require('../services/firestoreService');
const { sendTurnToFastApi, evaluateSession } = require('../services/fastApiService');
const { computeXpAward, computeLevel, computeStreak, computeNewBadges } = require('../services/xpService');

/**
 * Shared auto-recovery helper: if the Firestore user doc is missing (e.g. server
 * was down during sign-up), re-create it from JWT claims so the session can proceed.
 */
async function getOrRecoverUser(req) {
  let user = await getUserById(req.uid);
  if (!user) {
    if (req.name) {
      user = await upsertGoogleUser(req.uid, { email: req.email, name: req.name, photoURL: req.picture || null });
    } else {
      const fallbackName = req.email ? req.email.split('@')[0] : 'User';
      user = await createUser(req.uid, { email: req.email, name: fallbackName });
    }
    console.log(`[sessions] Auto-recovered Firestore doc for user ${req.uid}`);
  }
  return user;
}

const MAX_TURNS_PER_SESSION = 50;

// POST /sessions/start
async function startSession(req, res) {
  const { scenarioId, persona, tone, languageLevel } = req.body;
  const userId = req.uid;

  if (!scenarioId) {
    return res.status(400).json({ error: 'scenarioId is required' });
  }

  try {
    const scenario = await getScenarioById(scenarioId);
    if (!scenario) return res.status(404).json({ error: 'Scenario not found' });

    const user = await getOrRecoverUser(req);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (user.level < scenario.requiredLevel) {
      return res.status(403).json({ error: `Scenario requires level ${scenario.requiredLevel}` });
    }

    const sessionId = uuidv4();
    await createSession(sessionId, {
      userId,
      scenarioId,
      scenarioTitle: scenario.title || null,
      persona: persona || null,
      tone: tone || null,
      languageLevel: languageLevel || null,
    });
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

  // Bug2 fix: safely parse conversationHistory, reject malformed JSON early
  let history = [];
  if (conversationHistory) {
    try {
      history = JSON.parse(conversationHistory);
      if (!Array.isArray(history)) throw new Error('conversationHistory must be an array');
    } catch {
      return res.status(400).json({ error: 'conversationHistory must be valid JSON array' });
    }
  }

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });
    if (session.status !== 'in_progress') {
      return res.status(400).json({ error: 'Session is not in progress' });
    }

    // Robustness5: enforce turn limit
    const currentTurnCount = (session.turns || []).length;
    if (currentTurnCount >= MAX_TURNS_PER_SESSION * 2) {
      return res.status(400).json({ error: `Session has reached the maximum of ${MAX_TURNS_PER_SESSION} turns` });
    }

    const scenario = await getScenarioById(session.scenarioId);
    if (!scenario) return res.status(404).json({ error: 'Scenario not found' });
    if (!scenario.systemPrompt) {
      return res.status(422).json({ error: 'Scenario is missing a system prompt — cannot process turn' });
    }

    // Build an enhanced system prompt that incorporates the user's persona/tone/level choices.
    let finalSystemPrompt = scenario.systemPrompt;
    const modifiers = [];
    if (session.persona) modifiers.push(`You are roleplaying as: ${session.persona}.`);
    if (session.tone) modifiers.push(`Maintain a ${session.tone} tone throughout the conversation.`);
    if (session.languageLevel) modifiers.push(`Use ${session.languageLevel}-level language complexity.`);
    if (modifiers.length > 0) {
      finalSystemPrompt = modifiers.join(' ') + '\n\n' + scenario.systemPrompt;
    }

    const fastApiResult = await sendTurnToFastApi(
      audioFile.buffer,
      audioFile.originalname,
      sessionId,
      history,
      finalSystemPrompt
    );

    const { userTranscript, aiReply, aiAudioBase64 } = fastApiResult;

    await appendTurnsToSession(
      sessionId,
      createTurnDoc('user', userTranscript),
      createTurnDoc('ai', aiReply)
    );

    // Feature6: return turnCount so Flutter knows how many turns have happened
    const turnCount = Math.floor(currentTurnCount / 2) + 1;
    return res.status(200).json({ userTranscript, aiReply, aiAudioBase64, turnCount });
  } catch (err) {
    console.error('processTurn error:', err.message);
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Failed to process turn' });
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

    // Bug4 fix: reject empty sessions before calling FastAPI
    if (!session.turns || session.turns.length === 0) {
      await abandonSessionInDb(sessionId);
      return res.status(400).json({ error: 'No turns recorded — session abandoned' });
    }

    const startedAt = session.startedAt?.toDate ? session.startedAt.toDate() : new Date(session.startedAt);
    const durationSeconds = Math.round((Date.now() - startedAt.getTime()) / 1000);

    // Build full transcript string
    const rawTranscript = session.turns
      .map((t) => `${t.role === 'user' ? 'User' : 'AI'}: ${t.transcript}`)
      .join('\n');

    // Robustness4: fetch user and scenario in parallel (auto-recover user doc if missing)
    const [scenario, user] = await Promise.all([
      getScenarioById(session.scenarioId),
      getOrRecoverUser(req),
    ]);

    if (!scenario) return res.status(404).json({ error: 'Scenario not found' });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Bug3 fix: run evaluation BEFORE marking the session complete.
    // If FastAPI is down, the session stays in_progress so the user can retry.
    const evaluation = await evaluateSession(sessionId, rawTranscript, scenario.type);

    // Compute overall score from individual skill scores.
    const scoreValues = Object.values(evaluation.scores || {});
    const overallScore = scoreValues.length > 0
      ? Math.round(scoreValues.reduce((sum, v) => sum + v, 0) / scoreValues.length)
      : null;

    // Evaluation succeeded — now safe to finalize the session
    await completeSession(sessionId, durationSeconds, overallScore);

    // Write evaluation report
    const report = await writeEvaluationReport(sessionId, {
      userId,
      scores: evaluation.scores,
      fillerWordCount: evaluation.fillerWordCount,
      fillerWords: evaluation.fillerWords,
      strengths: evaluation.strengths,
      improvements: evaluation.improvements,
      recommendedNextType: evaluation.recommendedNextType,
      rawTranscript,
    });

    // XP + gamification
    const xpAwarded = computeXpAward(evaluation.scores);
    const oldLevel = user.level || 1;
    const newLevel = computeLevel((user.xp || 0) + xpAwarded);
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

    // Robustness2: use FieldValue.increment for atomic XP update (prevents race conditions)
    const userUpdates = {
      xp: FieldValue.increment(xpAwarded),
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
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Failed to end session' });
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
  const sessionId = req.body.sessionId || req.params.sessionId;
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
    // Surface Firestore index errors so they are visible in logs
    if (err.message && err.message.includes('index')) {
      console.error('⚠️  Firestore composite index missing for sessions(userId, startedAt).');
      console.error('   Fix: firebase deploy --only firestore:indexes');
      console.error('   Or create the index manually in Firebase Console.');
    }
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
