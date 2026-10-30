const { db } = require('../config/firebase');
const { computeActivityUpdate } = require('./xpService');

/*
 * The single place XP-earning activities write gamification state.
 *
 * Roleplay sessions, contests and learning levels all award XP; before this
 * existed only roleplay recomputed level/streak/badges, so contest and
 * learning XP left the level and streak shown in the app out of step.
 */

/**
 * Applies an activity's XP, level, streak, weekly XP and badges to the user
 * inside an existing transaction. `userData` must have been read with
 * `tx.get(userRef)` in the same transaction.
 *
 * @param {FirebaseFirestore.Transaction} tx
 * @param {FirebaseFirestore.DocumentReference} userRef
 * @param {object} userData
 * @param {object} activity        see xpService.computeActivityUpdate
 * @param {object} [extraUpdates]  more fields to write in the same update
 *                                 (dotted paths and FieldValue sentinels allowed)
 * @returns {object} summary — { xpAwarded, totalXp, newLevel, leveledUp, newStreak, newBadges }
 */
function applyActivityInTx(tx, userRef, userData, activity, extraUpdates = {}) {
  const { updates, summary } = computeActivityUpdate(userData, activity);
  tx.update(userRef, { ...updates, ...extraUpdates });
  return summary;
}

/**
 * Convenience wrapper that opens its own transaction.
 * `buildExtra(userData)` may return more fields derived from the fresh user doc.
 */
async function applyActivity(uid, activity, buildExtra = () => ({})) {
  const userRef = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) {
      const err = new Error('User not found');
      err.statusCode = 404;
      throw err;
    }
    const data = snap.data();
    return applyActivityInTx(tx, userRef, data, activity, buildExtra(data));
  });
}

module.exports = { applyActivityInTx, applyActivity };
