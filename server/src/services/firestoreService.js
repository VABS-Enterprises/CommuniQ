const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { createUserDoc, createGoogleUserDoc } = require('../models/userModel');
const { createSessionDoc } = require('../models/sessionModel');
const { createEvaluationDoc } = require('../models/evaluationModel');
const { stripSystemPrompt } = require('../models/scenarioModel');
const { createContestAttemptDoc } = require('../models/contestModel');
const { computeLevel, isoWeekKey } = require('./xpService');

// ─── Users ────────────────────────────────────────────────────────────────────

async function createUser(uid, data) {
  const userDoc = createUserDoc(uid, data);
  await db.collection('users').doc(uid).set(userDoc);
  return userDoc;
}

/**
 * Fields from `defaults` that `existing` is missing (undefined or null for
 * identity fields). A user document can be created by POST /onboarding before
 * registration finishes, so sign-in paths fill gaps instead of assuming a
 * document that exists is complete.
 */
function missingDefaults(existing, defaults) {
  const identity = new Set(['name', 'email', 'provider']);
  const patch = {};
  for (const [key, value] of Object.entries(defaults)) {
    if (key === 'createdAt' || key === 'lastLoginAt') continue;
    const current = existing[key];
    if (current === undefined || (identity.has(key) && !current)) patch[key] = value;
  }
  return patch;
}

/**
 * Used for email registration. Creates the user document, or completes one
 * that already exists (e.g. created by an onboarding sync that won the race).
 * Returns { user, created }.
 */
async function createOrCompleteUser(uid, { email, name }) {
  const ref = db.collection('users').doc(uid);
  const defaults = createUserDoc(uid, { email, name });
  const created = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, defaults);
      return true;
    }
    const patch = missingDefaults(snap.data(), defaults);
    if (Object.keys(patch).length > 0) tx.set(ref, patch, { merge: true });
    return false;
  });
  const fresh = await ref.get();
  return { user: fresh.data(), created };
}

/**
 * Used for Google and Apple sign-in.
 * If the user exists → refresh lastLoginAt and fill any missing defaults.
 * If new → create a full Firestore doc with defaults.
 * Returns the full user document in both cases.
 */
async function upsertGoogleUser(uid, { email, name, photoURL, provider = 'google' }) {
  const ref = db.collection('users').doc(uid);
  const defaults = { ...createGoogleUserDoc(uid, { email, name, photoURL }), provider };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, defaults);
      return;
    }
    tx.set(
      ref,
      { ...missingDefaults(snap.data(), defaults), lastLoginAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
  });

  const fresh = await ref.get();
  return fresh.data();
}

async function getUserById(uid) {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function updateUser(uid, updates) {
  await db.collection('users').doc(uid).update(updates);
}

/**
 * Deletes everything stored for a user: sessions, evaluation reports, contest
 * attempts, and the user document with all its subcollections (visualReports).
 * Must finish before the Firebase Auth account is removed.
 */
async function deleteUserData(uid) {
  const [sessionsSnap, reportsSnap, contestSnap] = await Promise.all([
    db.collection('sessions').where('userId', '==', uid).get(),
    db.collection('evaluationReports').where('userId', '==', uid).get(),
    db.collection('contestAttempts').where('userId', '==', uid).get(),
  ]);

  const refs = [
    ...sessionsSnap.docs.map((d) => d.ref),
    ...reportsSnap.docs.map((d) => d.ref),
    ...contestSnap.docs.map((d) => d.ref),
  ];

  // Firestore batch limit is 500 operations per commit
  const BATCH_SIZE = 499;
  for (let i = 0; i < refs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    refs.slice(i, i + BATCH_SIZE).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  // Deleting a document does not delete its subcollections — recursiveDelete
  // removes users/{uid}/visualReports along with the user document.
  await db.recursiveDelete(db.collection('users').doc(uid));
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
  // Aggregate count — billed as one read per 1000 matches instead of reading
  // every session document.
  const agg = await db
    .collection('sessions')
    .where('userId', '==', userId)
    .where('status', '==', 'completed')
    .count()
    .get();
  return agg.data().count;
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

// ─── Self-learning evaluation model (paper §3.4) ───────────────────────────────

async function getEvaluationModelDoc(scenarioType) {
  const snap = await db.collection('evaluationModel').doc(scenarioType).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function setEvaluationModelDoc(scenarioType, data) {
  await db.collection('evaluationModel').doc(scenarioType).set(data, { merge: true });
}

/**
 * Fetches recent evaluationReports across ALL scenario types in one query
 * (bounded by lookback + maxSample), rather than one query per type. The
 * retraining job groups these in memory by scenarioType — this keeps Loop A
 * to a single Firestore read per cycle regardless of how many scenario types
 * exist. Only requires a single-field index on generatedAt, which Firestore
 * provides automatically.
 */
async function getRecentEvaluationReportsAll(lookbackMs, maxSample = 2000) {
  const cutoff = new Date(Date.now() - lookbackMs);
  const snap = await db
    .collection('evaluationReports')
    .where('generatedAt', '>=', cutoff)
    .orderBy('generatedAt', 'desc')
    .limit(maxSample)
    .get();
  return snap.docs.map((d) => d.data());
}

// ─── Contests ─────────────────────────────────────────────────────────────────

async function createContestAttempt(attemptId, data) {
  const doc = createContestAttemptDoc(attemptId, data);
  await db.collection('contestAttempts').doc(attemptId).set(doc);
  return doc;
}

function _serializeContestAttempt(data) {
  const result = { ...data };
  if (result.submittedAt?.toDate) result.submittedAt = result.submittedAt.toDate().toISOString();
  return result;
}

/** Firestore's error code when a query needs a composite index that isn't deployed yet. */
const FAILED_PRECONDITION = 9;

function _isMissingIndex(err) {
  return err && (err.code === FAILED_PRECONDITION || /requires an index/i.test(err.message || ''));
}

function _millis(ts) {
  if (!ts) return 0;
  if (typeof ts.toMillis === 'function') return ts.toMillis();
  return new Date(ts).getTime() || 0;
}

/**
 * Uses the contestAttempts(userId ASC, submittedAt DESC) index
 * (server/firestore.indexes.json). Until that index is deployed, falls back
 * to an unordered equality query sorted in memory.
 */
async function getUserContestAttempts(userId, limitCount = 20) {
  let docs;
  try {
    const snap = await db
      .collection('contestAttempts')
      .where('userId', '==', userId)
      .orderBy('submittedAt', 'desc')
      .limit(limitCount)
      .get();
    docs = snap.docs.map((d) => d.data());
  } catch (err) {
    if (!_isMissingIndex(err)) throw err;
    console.warn('[contest] history index missing — falling back to in-memory sort');
    const snap = await db.collection('contestAttempts').where('userId', '==', userId).get();
    docs = snap.docs.map((d) => d.data());
    docs.sort((a, b) => _millis(b.submittedAt) - _millis(a.submittedAt));
    docs = docs.slice(0, limitCount);
  }
  return docs.map(_serializeContestAttempt);
}

/** Current display names for a set of uids — leaderboards show renames immediately. */
async function _currentNames(uids) {
  if (uids.length === 0) return new Map();
  const refs = uids.map((uid) => db.collection('users').doc(uid));
  const snaps = await db.getAll(...refs);
  const names = new Map();
  for (const snap of snaps) {
    if (snap.exists && snap.data().name) names.set(snap.id, snap.data().name);
  }
  return names;
}

/**
 * Leaderboard = each user's single best attempt, optionally filtered to one
 * contestType. Filtering by type happens in the query (contestType ASC,
 * overallScore DESC index) so a type's leaderboard isn't starved by attempts
 * of other types; per-user dedupe happens in memory.
 */
async function getContestLeaderboard(contestType, limitCount = 50) {
  const SCAN = 500;
  let snap;
  if (contestType) {
    try {
      snap = await db
        .collection('contestAttempts')
        .where('contestType', '==', contestType)
        .orderBy('overallScore', 'desc')
        .limit(SCAN)
        .get();
    } catch (err) {
      if (!_isMissingIndex(err)) throw err;
      console.warn('[contest] leaderboard index missing — falling back to unfiltered scan');
      snap = await db.collection('contestAttempts').orderBy('overallScore', 'desc').limit(SCAN).get();
    }
  } else {
    snap = await db.collection('contestAttempts').orderBy('overallScore', 'desc').limit(SCAN).get();
  }

  const bestByUser = new Map();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (contestType && data.contestType !== contestType) continue;
    const existing = bestByUser.get(data.userId);
    if (!existing || existing.overallScore < data.overallScore) {
      bestByUser.set(data.userId, {
        userId: data.userId,
        name: data.name,
        overallScore: data.overallScore,
        contestType: data.contestType,
        motion: data.motion,
      });
    }
  }
  const top = Array.from(bestByUser.values())
    .sort((a, b) => b.overallScore - a.overallScore)
    .slice(0, limitCount);

  const names = await _currentNames(top.map((e) => e.userId));
  return top.map((e) => ({ ...e, name: names.get(e.userId) || e.name }));
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

async function getTopUsersByXp(limit = 50) {
  const snap = await db
    .collection('users')
    .orderBy('xp', 'desc')
    .limit(limit)
    .get();
  return snap.docs.map((doc) => {
    const { name, xp, badges } = doc.data();
    return { uid: doc.id, name, xp: xp || 0, level: computeLevel(xp || 0), badges };
  });
}

/**
 * Top users by XP earned this ISO week (users.weeklyXp, written by
 * progressService for every XP-earning activity). Uses the users(weekKey ASC,
 * weeklyXp DESC) index, with an in-memory fallback until it is deployed.
 */
async function getWeeklyTopUsersByXp(limit = 50) {
  const weekKey = isoWeekKey();
  let docs;
  try {
    const snap = await db
      .collection('users')
      .where('weekKey', '==', weekKey)
      .orderBy('weeklyXp', 'desc')
      .limit(limit)
      .get();
    docs = snap.docs;
  } catch (err) {
    if (!_isMissingIndex(err)) throw err;
    console.warn('[leaderboard] weekly index missing — falling back to in-memory sort');
    const snap = await db.collection('users').where('weekKey', '==', weekKey).get();
    docs = snap.docs
      .sort((a, b) => (b.data().weeklyXp || 0) - (a.data().weeklyXp || 0))
      .slice(0, limit);
  }

  return docs.map((doc) => {
    const { name, weeklyXp, xp, badges } = doc.data();
    // `xp` carries the weekly figure so the client's existing row layout
    // ranks and labels by what the board is sorted on.
    return { uid: doc.id, name, xp: weeklyXp || 0, totalXp: xp || 0, level: computeLevel(xp || 0), badges };
  });
}

async function saveVisualReport(uid, reportData) {
  const { v4: uuidv4 } = require('uuid');
  const reportId = reportData.reportId || uuidv4();

  const docData = {
    reportId,
    userId: uid,
    visualEngagementScore: reportData.visualEngagementScore || 0,
    overallPostureScore: reportData.overallPostureScore || 0,
    eyeContactPercentage: reportData.eyeContactPercentage || 0,
    gazeStabilityPercentage: reportData.gazeStabilityPercentage || 0,
    spineAlignmentPercentage: reportData.spineAlignmentPercentage || 0,
    shoulderSymmetryPercentage: reportData.shoulderSymmetryPercentage || 0,
    chestOpennessPercentage: reportData.chestOpennessPercentage || 0,
    headTiltStabilityPercentage: reportData.headTiltStabilityPercentage || 0,
    handMovementPercentage: reportData.handMovementPercentage || 0,
    gestureScore: reportData.gestureScore || 0,
    insights: reportData.insights || [],
    sessionId: typeof reportData.sessionId === 'string' ? reportData.sessionId : null,
    createdAt: FieldValue.serverTimestamp(),
  };

  await db.collection('users').doc(uid).collection('visualReports').doc(reportId).set(docData);
  return docData;
}

async function getUserVisualReports(uid) {
  const snap = await db.collection('users').doc(uid).collection('visualReports').orderBy('createdAt', 'desc').limit(20).get();
  return snap.docs.map((doc) => {
    const data = doc.data();
    return { ...data, createdAt: data.createdAt?.toDate ? data.createdAt.toDate().toISOString() : data.createdAt };
  });
}

module.exports = {
  createUser,
  createOrCompleteUser,
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
  getEvaluationModelDoc,
  setEvaluationModelDoc,
  getRecentEvaluationReportsAll,
  createContestAttempt,
  getUserContestAttempts,
  getContestLeaderboard,
  saveVisualReport,
  getUserVisualReports,
};
