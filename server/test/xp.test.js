/*
 * Pure gamification logic: level from XP, streaks (stored vs. shown), ISO week
 * bucketing, and the combined update every XP-earning activity applies.
 */
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const xp = require(path.join(__dirname, '..', 'src/services/xpService.js'));

const day = (iso) => new Date(`${iso}T12:00:00`);

test('level follows the XP thresholds', () => {
  assert.strictEqual(xp.computeLevel(0), 1);
  assert.strictEqual(xp.computeLevel(299), 1);
  assert.strictEqual(xp.computeLevel(300), 2);
  assert.strictEqual(xp.computeLevel(2000), 5);
  assert.strictEqual(xp.computeLevel(99999), 5);
});

test('streak continues on consecutive days and resets after a gap', () => {
  const now = day('2026-10-31');
  assert.strictEqual(xp.computeStreak(null, 0, now), 1);
  assert.strictEqual(xp.computeStreak(day('2026-10-31'), 4, now), 4);
  assert.strictEqual(xp.computeStreak(day('2026-10-30'), 4, now), 5);
  assert.strictEqual(xp.computeStreak(day('2026-10-28'), 4, now), 1);
});

test('a same-day activity never reports a zero streak', () => {
  assert.strictEqual(xp.computeStreak(day('2026-10-31'), 0, day('2026-10-31')), 1);
});

test('the shown streak drops to 0 once a day is missed', () => {
  const now = day('2026-10-31');
  assert.strictEqual(xp.effectiveStreak(day('2026-10-31'), 6, now), 6);
  assert.strictEqual(xp.effectiveStreak(day('2026-10-30'), 6, now), 6);
  assert.strictEqual(xp.effectiveStreak(day('2026-10-29'), 6, now), 0);
  assert.strictEqual(xp.effectiveStreak(null, 6, now), 0);
});

test('ISO week keys match the calendar, including year boundaries', () => {
  assert.strictEqual(xp.isoWeekKey(day('2026-10-31')), '2026-W44');
  assert.strictEqual(xp.isoWeekKey(day('2026-01-01')), '2026-W01');
  assert.strictEqual(xp.isoWeekKey(day('2027-01-01')), '2026-W53');
});

test('an activity updates xp, level, streak and weekly xp together', () => {
  const now = day('2026-10-31');
  const user = { xp: 280, level: 1, streak: 2, lastActiveDate: day('2026-10-30'), badges: [] };
  const { updates, summary } = xp.computeActivityUpdate(user, { xpAwarded: 40, now });
  assert.strictEqual(updates.xp, 320);
  assert.strictEqual(updates.level, 2);
  assert.strictEqual(updates.streak, 3);
  assert.strictEqual(updates.weekKey, '2026-W44');
  assert.strictEqual(updates.weeklyXp, 40);
  assert.strictEqual(summary.leveledUp, true);
  assert.deepStrictEqual(updates.badges, ['level_up']);
});

test('weekly xp accumulates within a week and restarts in a new one', () => {
  const now = day('2026-10-31');
  const sameWeek = { xp: 0, weekKey: '2026-W44', weeklyXp: 70 };
  assert.strictEqual(xp.computeActivityUpdate(sameWeek, { xpAwarded: 30, now }).updates.weeklyXp, 100);
  const lastWeek = { xp: 0, weekKey: '2026-W43', weeklyXp: 500 };
  assert.strictEqual(xp.computeActivityUpdate(lastWeek, { xpAwarded: 30, now }).updates.weeklyXp, 30);
});

test('a stale stored level (from old onboarding) does not fake a level-up', () => {
  // Self-assessed "Advanced" used to write level 3 at 0 XP.
  const user = { xp: 0, level: 3, badges: [] };
  const { updates, summary } = xp.computeActivityUpdate(user, { xpAwarded: 20 });
  assert.strictEqual(updates.level, 1);
  assert.strictEqual(summary.leveledUp, false);
});

test('existing badges are kept and not re-awarded', () => {
  const user = { xp: 0, badges: ['first_session'] };
  const { updates } = xp.computeActivityUpdate(user, { xpAwarded: 20, completedSessionCount: 3 });
  assert.strictEqual(updates.badges, undefined);
});
