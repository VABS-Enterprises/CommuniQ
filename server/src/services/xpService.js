/**
 * XP, levelling, streak, and badge logic.
 * All pure — Firestore writes are done by progressService, which applies the
 * update computed by computeActivityUpdate inside a transaction.
 */

/** XP for finishing a learning level for the first time. */
const LEARNING_LEVEL_XP = 30;

const LEVEL_THRESHOLDS = [
  { level: 1, xpRequired: 0 },
  { level: 2, xpRequired: 300 },
  { level: 3, xpRequired: 700 },
  { level: 4, xpRequired: 1200 },
  { level: 5, xpRequired: 2000 },
];

/**
 * Returns XP to award based on average evaluation score.
 */
function computeXpAward(scores) {
  const values = Object.values(scores);
  const avg = values.reduce((sum, v) => sum + v, 0) / values.length;

  if (avg >= 80) return 100;
  if (avg >= 60) return 70;
  if (avg >= 40) return 40;
  return 20;
}

/**
 * Returns the level a user should be at given total XP.
 */
function computeLevel(totalXp) {
  let level = 1;
  for (const threshold of LEVEL_THRESHOLDS) {
    if (totalXp >= threshold.xpRequired) level = threshold.level;
  }
  return level;
}

/**
 * Computes new streak value.
 * @param {FirebaseFirestore.Timestamp|null} lastActiveDate
 * @param {number} currentStreak
 * @returns {number}
 */
function computeStreak(lastActiveDate, currentStreak, now = new Date()) {
  const diffDays = daysSince(lastActiveDate, now);
  if (diffDays === null) return 1;

  if (diffDays === 0) return Math.max(currentStreak, 1); // already practiced today
  if (diffDays === 1) return currentStreak + 1;          // consecutive day
  return 1;                                               // streak broken
}

/** Whole calendar days between lastActiveDate and now, or null if never active. */
function daysSince(lastActiveDate, now = new Date()) {
  if (!lastActiveDate) return null;
  const last = lastActiveDate.toDate ? lastActiveDate.toDate() : new Date(lastActiveDate);
  if (isNaN(last.getTime())) return null;

  const today = new Date(now);
  today.setHours(0, 0, 0, 0);
  last.setHours(0, 0, 0, 0);
  return Math.round((today - last) / (1000 * 60 * 60 * 24));
}

/**
 * The streak to show the user. The stored value only changes when they
 * practise, so a streak broken by inactivity has to be zeroed on read.
 */
function effectiveStreak(lastActiveDate, storedStreak, now = new Date()) {
  const diffDays = daysSince(lastActiveDate, now);
  if (diffDays === null || diffDays > 1) return 0;
  return storedStreak || 0;
}

/** ISO-8601 week key, e.g. "2026-W44". Used to bucket weekly XP. */
function isoWeekKey(now = new Date()) {
  const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

/**
 * Returns array of new badge IDs to award.
 * @param {object} params
 * @param {string[]} params.existingBadges
 * @param {number}   params.completedSessionCount - total after this session
 * @param {number}   params.newStreak
 * @param {object}   params.scores - { clarity, fluency, ... }
 * @param {boolean}  params.leveledUp
 * @returns {string[]}
 */
function computeNewBadges({ existingBadges, completedSessionCount, newStreak, scores, leveledUp }) {
  const earned = new Set(existingBadges);
  const toAward = [];

  function maybeAward(badge) {
    if (!earned.has(badge)) toAward.push(badge);
  }

  if (completedSessionCount != null && completedSessionCount >= 1) maybeAward('first_session');
  if (newStreak >= 7) maybeAward('7_day_streak');
  if (newStreak >= 30) maybeAward('30_day_streak');
  if (Object.values(scores || {}).some((v) => v === 100)) maybeAward('perfect_score');
  if (leveledUp) maybeAward('level_up');

  return toAward;
}

/**
 * Everything an XP-earning activity (roleplay, contest, learning level)
 * changes on the user document, computed from the user's current data.
 *
 * Returns plain values (no FieldValue sentinels) so it can be unit-tested and
 * applied inside a transaction that read `user`.
 *
 * @param {object} user                       current users/{uid} data
 * @param {object} activity
 * @param {number} activity.xpAwarded
 * @param {object} [activity.scores]          roleplay dimension scores, for badges
 * @param {number} [activity.completedSessionCount] roleplay sessions incl. this one
 * @param {Date}   [activity.now]
 */
function computeActivityUpdate(user, { xpAwarded, scores = {}, completedSessionCount = null, now = new Date() }) {
  const prevXp = user.xp || 0;
  const totalXp = prevXp + xpAwarded;
  // Derive the old level from XP rather than trusting the stored field, which
  // older onboarding code overwrote with a self-assessed level.
  const oldLevel = computeLevel(prevXp);
  const newLevel = computeLevel(totalXp);
  const leveledUp = newLevel > oldLevel;
  const newStreak = computeStreak(user.lastActiveDate, user.streak || 0, now);

  const existingBadges = Array.isArray(user.badges) ? user.badges : [];
  const newBadges = computeNewBadges({
    existingBadges,
    completedSessionCount,
    newStreak,
    scores,
    leveledUp,
  });

  const weekKey = isoWeekKey(now);
  const weeklyXp = (user.weekKey === weekKey ? user.weeklyXp || 0 : 0) + xpAwarded;

  return {
    updates: {
      xp: totalXp,
      level: newLevel,
      streak: newStreak,
      lastActiveDate: now,
      weekKey,
      weeklyXp,
      ...(newBadges.length > 0 && { badges: [...existingBadges, ...newBadges] }),
    },
    summary: { xpAwarded, totalXp, newLevel, leveledUp, newStreak, newBadges },
  };
}

module.exports = {
  LEARNING_LEVEL_XP,
  computeXpAward,
  computeLevel,
  computeStreak,
  computeNewBadges,
  daysSince,
  effectiveStreak,
  isoWeekKey,
  computeActivityUpdate,
};
