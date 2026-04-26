const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { createUserDoc, createGoogleUserDoc } = require('../models/userModel');
const { createSessionDoc } = require('../models/sessionModel');
const { createEvaluationDoc } = require('../models/evaluationModel');
const { stripSystemPrompt } = require('../models/scenarioModel');

// ─── Users ────────────────────────────────────────────────────────────────────

async function createUser(uid, data) {
  const userDoc = createUserDoc(uid, data);
  await db.collection('users').doc(uid).set(userDoc);
  return userDoc;
}

/**
 * Used for Google Sign-In.
 * If the user exists → only update lastLoginAt.
 * If new → create a full Firestore doc with defaults.
 * Returns the full user document in both cases.
 */
async function upsertGoogleUser(uid, { email, name, photoURL }) {
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();

  if (snap.exists) {
    // Returning user — just refresh lastLoginAt
    await ref.update({ lastLoginAt: FieldValue.serverTimestamp() });
    const updated = await ref.get();
    return updated.data();
  }

  // New Google user — create full doc
  const userDoc = createGoogleUserDoc(uid, { email, name, photoURL });
  await ref.set(userDoc);
  return userDoc;
}

async function getUserById(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function updateUser(uid, updates) {
  await db.collection('users').doc(uid).update(updates);
}

async function deleteUserData(uid) {
  const [sessionsSnap, reportsSnap] = await Promise.all([
    db.collection('sessions').where('userId', '==', uid).get(),
    db.collection('evaluationReports').where('userId', '==', uid).get(),
  ]);

  const refs = [
    ...sessionsSnap.docs.map((d) => d.ref),
    ...reportsSnap.docs.map((d) => d.ref),
    db.collection('users').doc(uid),
  ];

  // Firestore batch limit is 500 operations per commit
  const BATCH_SIZE = 499;
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    refs.slice(i, i + BATCH_SIZE).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

// ─── Sessions ─────────────────────────────────────────────────────────────────

async function createSession(sessionId, data) {
  const sessionDoc = createSessionDoc(sessionId, data);
  await db.collection('sessions').doc(sessionId).set(sessionDoc);
  return sessionDoc;
}

async function getSessionById(sessionId) {
  const snap = await db.collection('sessions').doc(sessionId).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function appendTurnsToSession(sessionId, userTurn, aiTurn) {
  await db.collection('sessions').doc(sessionId).update({
    turns: FieldValue.arrayUnion(userTurn, aiTurn),
  });
}

/** Persist the Colab-parity opening line (AI only, no user turn yet). */
async function appendAiTurnOnly(sessionId, aiTurn) {
  await db.collection('sessions').doc(sessionId).update({
    turns: FieldValue.arrayUnion(aiTurn),
  });
}

/** Append one or more turns from the Pipecat live-voice pipeline (same shape as HTTP /turn). */
async function appendLiveVoiceTurns(sessionId, turnDocs) {
  if (!turnDocs || turnDocs.length === 0) return;
  await db.collection('sessions').doc(sessionId).update({
    turns: FieldValue.arrayUnion(...turnDocs),
  });
}

async function completeSession(sessionId, durationSeconds, overallScore) {
  await db.collection('sessions').doc(sessionId).update({
    status: 'completed',
    endedAt: FieldValue.serverTimestamp(),
    durationSeconds,
    ...(overallScore != null ? { overallScore } : {}),
  });
}

async function countCompletedSessions(userId) {
  const snap = await db
    .collection('sessions')
    .where('userId', '==', userId)
    .where('status', '==', 'completed')
    .get();
  return snap.size;
}

async function abandonSession(sessionId) {
  await db.collection('sessions').doc(sessionId).update({
    status: 'abandoned',
    endedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Returns all sessions that are still 'in_progress' and started more than
 * maxAgeMs milliseconds ago. Used by the stale session cleanup job.
 *
 * Queries only by status (equality — no composite index required) and filters
 * by age in memory to avoid the need for a composite Firestore index.
 */
async function getStaleInProgressSessions(maxAgeMs = 2 * 60 * 60 * 1000) {
  const snap = await db
    .collection('sessions')
    .where('status', '==', 'in_progress')
    .get();

  const cutoff = Date.now() - maxAgeMs;
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((session) => {
      const startedAt = session.startedAt?.toDate
        ? session.startedAt.toDate().getTime()
        : new Date(session.startedAt).getTime();
      return !isNaN(startedAt) && startedAt < cutoff;
    });
}

async function getUserSessions(userId, limitCount = 20) {
  // Requires a Firestore composite index: sessions(userId ASC, startedAt DESC).
  // If you see "requires an index" errors, open the URL in the error message
  // or run: firebase deploy --only firestore:indexes
  const snap = await db
    .collection('sessions')
    .where('userId', '==', userId)
    .orderBy('startedAt', 'desc')
    .limit(limitCount)
    .get();
  return snap.docs.map((doc) => _serializeSessionDoc(doc.data()));
}

/**
 * Convert Firestore Timestamp fields in a session document to ISO-8601 strings
 * so the Flutter client always receives plain strings, never raw Timestamp objects.
 *
 * Firestore Admin returns Timestamp objects (with .toDate()) from doc.data().
 * JSON.stringify() serialises them as { _seconds, _nanoseconds } — a Map in Dart —
 * which causes a runtime cast error when Flutter does `as String?`.
 */
function _serializeSessionDoc(data) {
  const result = { ...data };
  for (const key of ['startedAt', 'endedAt']) {
    const val = result[key];
    if (val == null) continue;
    if (typeof val.toDate === 'function') {
      // Firestore Admin Timestamp object
      result[key] = val.toDate().toISOString();
    } else if (typeof val._seconds === 'number') {
      // Already-serialised Firestore Timestamp ({ _seconds, _nanoseconds })
      result[key] = new Date(val._seconds * 1000).toISOString();
    }
    // If it's already a string, leave it as-is
  }
  return result;
}

// ─── Evaluation Reports ───────────────────────────────────────────────────────

async function writeEvaluationReport(sessionId, data) {
  const report = createEvaluationDoc(sessionId, data);
  await db.collection('evaluationReports').doc(sessionId).set(report);
  return report;
}

async function getEvaluationReport(sessionId) {
  const snap = await db.collection('evaluationReports').doc(sessionId).get();
  if (!snap.exists) return null;
  return snap.data();
}

// ─── Scenarios ────────────────────────────────────────────────────────────────

async function getScenariosForLevel(userLevel) {
  const snap = await db
    .collection('scenarios')
    .where('requiredLevel', '<=', userLevel)
    .get();
  // Robustness6: deterministic order — level ascending, then difficulty ascending
  return snap.docs
    .map((doc) => stripSystemPrompt(doc.data()))
    .sort((a, b) => a.requiredLevel - b.requiredLevel || a.difficulty - b.difficulty);
}

async function getScenarioById(scenarioId) {
  const snap = await db.collection('scenarios').doc(scenarioId).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function createScenario(data) {
  const ref = db.collection('scenarios').doc(data.scenarioId);
  await ref.set(data);
  return data;
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

async function getTopUsersByXp(limit = 50) {
  const snap = await db
    .collection('users')
    .orderBy('xp', 'desc')
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const { name, xp, level, badges } = doc.data();
    return { name, xp, level, badges };
  });
}

async function getWeeklyTopUsersByXp(limit = 50) {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  // Firestore inequality filter requires the same field to be ordered first,
  // so we sort by xp in memory after filtering by lastActiveDate.
  const snap = await db
    .collection('users')
    .where('lastActiveDate', '>=', sevenDaysAgo)
    .get();

  return snap.docs
    .map((doc) => {
      const { name, xp, level, badges } = doc.data();
      return { name, xp, level, badges };
    })
    .sort((a, b) => b.xp - a.xp)
    .slice(0, limit);
}

module.exports = {
  createUser,
  upsertGoogleUser,
  getUserById,
  updateUser,
  deleteUserData,
  createSession,
  getSessionById,
  appendTurnsToSession,
  appendAiTurnOnly,
  appendLiveVoiceTurns,
  completeSession,
  abandonSession,
  getStaleInProgressSessions,
  countCompletedSessions,
  getUserSessions,
  writeEvaluationReport,
  getEvaluationReport,
  getScenariosForLevel,
  getScenarioById,
  createScenario,
  getTopUsersByXp,
  getWeeklyTopUsersByXp,
};
