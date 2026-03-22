const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { createUserDoc } = require('../models/userModel');
const { createSessionDoc } = require('../models/sessionModel');
const { createEvaluationDoc } = require('../models/evaluationModel');
const { stripSystemPrompt } = require('../models/scenarioModel');

// ─── Users ────────────────────────────────────────────────────────────────────

async function createUser(uid, data) {
  const userDoc = createUserDoc(uid, data);
  await db.collection('users').doc(uid).set(userDoc);
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

async function completeSession(sessionId, durationSeconds) {
  await db.collection('sessions').doc(sessionId).update({
    status: 'completed',
    endedAt: FieldValue.serverTimestamp(),
    durationSeconds,
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

async function getUserSessions(userId, limitCount = 20) {
  const snap = await db
    .collection('sessions')
    .where('userId', '==', userId)
    .orderBy('startedAt', 'desc')
    .limit(limitCount)
    .get();
  return snap.docs.map((doc) => doc.data());
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
  return snap.docs.map((doc) => stripSystemPrompt(doc.data()));
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
  getUserById,
  updateUser,
  deleteUserData,
  createSession,
  getSessionById,
  appendTurnsToSession,
  completeSession,
  abandonSession,
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
