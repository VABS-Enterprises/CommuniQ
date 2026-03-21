/**
 * XP, levelling, streak, and badge logic.
 * All Firestore writes are done by the caller (sessionController)
 * after receiving the computed delta from these pure functions.
 */

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
function computeStreak(lastActiveDate, currentStreak) {
  if (!lastActiveDate) return 1;

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const last = lastActiveDate.toDate ? lastActiveDate.toDate() : new Date(lastActiveDate);
  last.setHours(0, 0, 0, 0);

  const diffDays = Math.round((today - last) / (1000 * 60 * 60 * 24));

  if (diffDays === 0) return currentStreak;        // already practiced today
  if (diffDays === 1) return currentStreak + 1;    // consecutive day
  return 1;                                         // streak broken
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

  if (completedSessionCount === 1) maybeAward('first_session');
  if (newStreak >= 7) maybeAward('7_day_streak');
  if (newStreak >= 30) maybeAward('30_day_streak');
  if (Object.values(scores).some((v) => v === 100)) maybeAward('perfect_score');
  if (leveledUp) maybeAward('level_up');

  return toAward;
}

module.exports = { computeXpAward, computeLevel, computeStreak, computeNewBadges };
