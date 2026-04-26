const { v4: uuidv4 } = require('uuid');
const { FieldValue } = require('firebase-admin/firestore');
const { createTurnDoc } = require('../models/sessionModel');
const {
  createSession,
  getSessionById,
  getScenarioById,
  appendTurnsToSession,
  appendAiTurnOnly,
  appendLiveVoiceTurns,
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
const {
  sendTurnToFastApi,
  sendOpeningToFastApi,
  evaluateSession,
} = require('../services/fastApiService');
const { computeXpAward, computeLevel, computeStreak, computeNewBadges } = require('../services/xpService');
const livekit = require('../services/livekitService');

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

/**
 * Resolve the base system prompt for a session.
 * For custom sessions (scenarioPrompt flow) the prompt is stored directly on
 * the session document. For Firestore-backed sessions it is fetched from the
 * scenarios collection. Returns { basePrompt, scenarioType }.
 */
async function resolveSystemPrompt(session) {
  if (session.customSystemPrompt) {
    return { basePrompt: session.customSystemPrompt, scenarioType: 'custom' };
  }
  const scenario = await getScenarioById(session.scenarioId);
  if (!scenario) throw Object.assign(new Error('Scenario not found'), { statusCode: 404 });
  if (!scenario.systemPrompt) {
    throw Object.assign(new Error('Scenario is missing a system prompt'), { statusCode: 422 });
  }
  return { basePrompt: scenario.systemPrompt, scenarioType: scenario.type || 'custom' };
}

/**
 * Build the final system prompt by prepending persona/tone/level/role/traits
 * modifiers to the base prompt and appending an optional backstory.
 */
function buildFinalPrompt(basePrompt, session) {
  const modifiers = [];
  if (session.persona) modifiers.push(`You are roleplaying as: ${session.persona}.`);
  if (session.tone) modifiers.push(`Maintain a ${session.tone} tone throughout the conversation.`);
  if (session.languageLevel) modifiers.push(`Use ${session.languageLevel}-level language complexity.`);
  if (session.role) modifiers.push(`The user is playing the role of: ${session.role}.`);
  if (session.traits) modifiers.push(`Your personality traits are: ${session.traits}.`);

  let prompt = modifiers.length > 0
    ? modifiers.join(' ') + '\n\n' + basePrompt
    : basePrompt;

  if (session.backstory) {
    prompt += `\n\nAdditional context: ${session.backstory}`;
  }
  return prompt;
}

// POST /sessions/start
// Accepts either a Firestore-backed scenarioId OR a scenarioPrompt (custom session).
async function startSession(req, res) {
  const { scenarioId, scenarioPrompt, scenarioTitle: clientTitle, persona, tone, languageLevel, role, traits, backstory } = req.body;
  const userId = req.uid;

  if (!scenarioId && !scenarioPrompt) {
    return res.status(400).json({ error: 'Provide either scenarioId or scenarioPrompt' });
  }

  try {
    const user = await getOrRecoverUser(req);
    if (!user) return res.status(404).json({ error: 'User not found' });

    let resolvedTitle = clientTitle || null;
    let customSystemPrompt = null;

    if (scenarioId) {
      // ── Firestore-backed scenario ──────────────────────────────────────────
      const scenario = await getScenarioById(scenarioId);
      if (!scenario) return res.status(404).json({ error: 'Scenario not found' });
      if (user.level < scenario.requiredLevel) {
        return res.status(403).json({ error: `Scenario requires level ${scenario.requiredLevel}` });
      }
      resolvedTitle = resolvedTitle || scenario.title || null;
    } else {
      // ── Custom / prompt-based scenario ─────────────────────────────────────
      customSystemPrompt = scenarioPrompt.trim();
      if (!customSystemPrompt) {
        return res.status(400).json({ error: 'scenarioPrompt cannot be empty' });
      }
    }

    const sessionId = uuidv4();
    await createSession(sessionId, {
      userId,
      scenarioId: scenarioId || null,
      scenarioTitle: resolvedTitle,
      persona: persona || null,
      tone: tone || null,
      languageLevel: languageLevel || null,
      customSystemPrompt,
      role: role || null,
      traits: traits || null,
      backstory: backstory || null,
    });

    // CP2: create the LiveKit room. No-op when LIVEKIT_ENABLED=false.
    await livekit.createRoom(sessionId);

    return res.status(201).json({ sessionId });
  } catch (err) {
    console.error('startSession error:', err.message);
    return res.status(500).json({ error: 'Could not start session' });
  }
}

// POST /sessions/opening — AI speaks first (no user audio); Colab parity.
async function sessionOpening(req, res) {
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
    if (session.turns && session.turns.length > 0) {
      return res.status(400).json({ error: 'Opening already recorded for this session' });
    }

    const { basePrompt } = await resolveSystemPrompt(session);
    const finalSystemPrompt = buildFinalPrompt(basePrompt, session);

    const fastApiResult = await sendOpeningToFastApi(sessionId, finalSystemPrompt);
    const { aiReply, aiAudioBase64 } = fastApiResult;

    await appendAiTurnOnly(sessionId, createTurnDoc('ai', aiReply));

    // CP2: dispatch the Pipecat agent into the LiveKit room so it is ready
    // to receive audio as soon as Flutter joins.
    // Pass the opening AI line so Pipecat seeds its LLM context with it —
    // this prevents the bot from re-introducing itself on the first user turn.
    // No-op when LIVEKIT_ENABLED=false (classic HTTP mode).
    await livekit.dispatchAgent(sessionId, finalSystemPrompt, aiReply);

    return res.status(200).json({
      aiReply,
      aiAudioBase64,
      liveVoiceEnabled: livekit.ENABLED,
    });
  } catch (err) {
    console.error('sessionOpening error:', err.message);
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Failed to generate opening' });
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

    // Robustness5: max user turns (opener is AI-only and does not count).
    const userTurnCount = (session.turns || []).filter((t) => t.role === 'user').length;
    if (userTurnCount >= MAX_TURNS_PER_SESSION) {
      return res.status(400).json({ error: `Session has reached the maximum of ${MAX_TURNS_PER_SESSION} turns` });
    }

    const { basePrompt } = await resolveSystemPrompt(session);
    const finalSystemPrompt = buildFinalPrompt(basePrompt, session);

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

    // Feature6: completed user turns after this request = userTurnCount + 1
    const turnCount = userTurnCount + 1;
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

    // Reject sessions with nothing to evaluate (no opener, no exchanges).
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

    // Fetch user (auto-recover if doc missing). For custom sessions there is no
    // Firestore scenario document — resolve both in parallel when possible.
    const scenarioFetch = session.scenarioId
      ? getScenarioById(session.scenarioId)
      : Promise.resolve(null);

    const [scenario, user] = await Promise.all([scenarioFetch, getOrRecoverUser(req)]);

    if (session.scenarioId && !scenario) {
      return res.status(404).json({ error: 'Scenario not found' });
    }
    if (!user) return res.status(404).json({ error: 'User not found' });

    const scenarioType = scenario?.type || 'custom';

    // Bug3 fix: run evaluation BEFORE marking the session complete.
    const evaluation = await evaluateSession(sessionId, rawTranscript, scenarioType);

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

    // Rolling per-skill averages — used by the progress/improvement cards on Home.
    // Formula: newAvg = (prevAvg * prevSessions + newScore) / (prevSessions + 1)
    const prevProgress = user.skillProgress || {};
    const updatedSkillProgress = {};
    for (const [skill, score] of Object.entries(evaluation.scores || {})) {
      const prev = prevProgress[skill] || { avg: 0, sessions: 0 };
      const newSessions = prev.sessions + 1;
      updatedSkillProgress[skill] = {
        avg: Math.round((prev.avg * prev.sessions + score) / newSessions),
        sessions: newSessions,
      };
    }

    // Robustness2: use FieldValue.increment for atomic XP update (prevents race conditions)
    const userUpdates = {
      xp: FieldValue.increment(xpAwarded),
      level: newLevel,
      streak: newStreak,
      lastActiveDate: FieldValue.serverTimestamp(),
      skillProgress: updatedSkillProgress,
    };
    if (newBadges.length > 0) {
      userUpdates.badges = FieldValue.arrayUnion(...newBadges);
    }
    await updateUser(userId, userUpdates);

    // Return a clean report object — do NOT forward the Firestore document directly
    // because it contains FieldValue.serverTimestamp() which serialises as a raw
    // internal object rather than a real timestamp.
    // CP2: clean up the LiveKit room after the session is fully evaluated.
    // No-op when LIVEKIT_ENABLED=false (classic HTTP mode).
    await livekit.deleteRoom(sessionId);

    return res.status(200).json({
      report: {
        scores: evaluation.scores,
        fillerWordCount: evaluation.fillerWordCount,
        fillerWords: evaluation.fillerWords,
        strengths: evaluation.strengths,
        improvements: evaluation.improvements,
        recommendedNextType: evaluation.recommendedNextType,
        rawTranscript,
      },
      xpAwarded,
      newLevel,
      leveledUp,
      newBadges,
      newStreak,
    });
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
    // Clean up the LiveKit room so it doesn't linger as an orphan.
    await livekit.deleteRoom(sessionId);
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

// POST /sessions/internal/live-voice-turn (Pipecat worker only, X-Communiq-Worker-Secret)
// Appends user and/or AI transcript turns so /sessions/end evaluation sees live voice.
async function appendLiveVoiceTurn(req, res) {
  const { sessionId, userTranscript, aiTranscript } = req.body || {};

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId is required' });
  }
  const u = userTranscript != null ? String(userTranscript).trim() : '';
  const a = aiTranscript != null ? String(aiTranscript).trim() : '';
  if (!u && !a) {
    return res.status(400).json({ error: 'Provide userTranscript and/or aiTranscript' });
  }

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.status !== 'in_progress') {
      return res.status(400).json({ error: 'Session is not in progress' });
    }

    const userTurnCount = (session.turns || []).filter((t) => t.role === 'user').length;
    if (u && userTurnCount >= MAX_TURNS_PER_SESSION) {
      return res.status(400).json({
        error: `Session has reached the maximum of ${MAX_TURNS_PER_SESSION} user turns`,
      });
    }

    const turns = [];
    if (u) turns.push(createTurnDoc('user', u));
    if (a) turns.push(createTurnDoc('ai', a));

    await appendLiveVoiceTurns(sessionId, turns);
    return res.status(200).json({ ok: true, appended: turns.length });
  } catch (err) {
    console.error('appendLiveVoiceTurn error:', err.message);
    return res.status(500).json({ error: 'Could not append live voice turn' });
  }
}

// POST /sessions/livekit-token
// Returns a LiveKit access token so Flutter can join the session's WebRTC room.
// Called by Flutter after startSession, before joining the LiveKit room.
async function getLivekitToken(req, res) {
  const { sessionId } = req.body;
  const userId = req.uid;

  if (!sessionId) {
    return res.status(400).json({ error: 'sessionId is required' });
  }

  if (!livekit.ENABLED) {
    return res.status(503).json({
      error: 'Live voice mode is not enabled. Set LIVEKIT_ENABLED=true on the server.',
    });
  }

  try {
    const session = await getSessionById(sessionId);
    if (!session) return res.status(404).json({ error: 'Session not found' });
    if (session.userId !== userId) return res.status(403).json({ error: 'Forbidden' });

    const { token, livekitUrl } = await livekit.createUserToken(sessionId, userId);
    return res.status(200).json({ token, livekitUrl });
  } catch (err) {
    console.error('getLivekitToken error:', err.message);
    return res.status(500).json({ error: 'Could not generate LiveKit token' });
  }
}

module.exports = {
  startSession,
  sessionOpening,
  processTurn,
  endSession,
  getReport,
  abandonSession,
  getSessionHistory,
  getSession,
  getLivekitToken,
  appendLiveVoiceTurn,
};
