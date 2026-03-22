const { FieldValue } = require('firebase-admin/firestore');

/*
 * Firestore shape — users/{uid}
 * ─────────────────────────────
 * uid            string     Firebase Auth uid
 * email          string
 * name           string
 * photoURL       string     profile picture (from Google or null)
 * provider       string     "google" | "email"
 * createdAt      timestamp
 * lastLoginAt    timestamp  updated on every sign-in
 * xp             number     starts at 0
 * level          number     1–5, unlocked by XP thresholds
 * streak         number     consecutive days practiced
 * lastActiveDate timestamp  updated on every completed session
 * badges         string[]   e.g. ["first_session", "7_day_streak"]
 * isPremium      boolean    false by default
 */

/**
 * Creates a brand-new user document for email/password registration.
 */
function createUserDoc(uid, { email, name }) {
  return {
    uid,
    email,
    name,
    photoURL: null,
    provider: 'email',
    createdAt: FieldValue.serverTimestamp(),
    lastLoginAt: FieldValue.serverTimestamp(),
    xp: 0,
    level: 1,
    streak: 0,
    lastActiveDate: null,
    badges: [],
    isPremium: false,
  };
}

/**
 * Creates a brand-new user document for Google Sign-In.
 * displayName and photoURL come from the Google account.
 */
function createGoogleUserDoc(uid, { email, name, photoURL }) {
  return {
    uid,
    email,
    name: name || email.split('@')[0],
    photoURL: photoURL || null,
    provider: 'google',
    createdAt: FieldValue.serverTimestamp(),
    lastLoginAt: FieldValue.serverTimestamp(),
    xp: 0,
    level: 1,
    streak: 0,
    lastActiveDate: null,
    badges: [],
    isPremium: false,
  };
}

module.exports = { createUserDoc, createGoogleUserDoc };
