const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — users/{uid}
 * ─────────────────────────────
 * uid            string     Firebase Auth uid
 * email          string
 * name           string
 * createdAt      timestamp
 * xp             number     starts at 0
 * level          number     1–5, unlocked by XP thresholds
 * streak         number     consecutive days practiced
 * lastActiveDate timestamp  updated on every completed session
 * badges         string[]   e.g. ["first_session", "7_day_streak"]
 * isPremium      boolean    false by default
 */

function createUserDoc(uid, { email, name }) {
  return {
    uid,
    email,
    name,
    createdAt: FieldValue.serverTimestamp(),
    xp: 0,
    level: 1,
    streak: 0,
    lastActiveDate: null,
    badges: [],
    isPremium: false,
  };
}

module.exports = { createUserDoc };
