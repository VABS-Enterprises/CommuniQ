/*
 * One-time repair for users whose `level` was overwritten by onboarding.
 *
 * Older onboarding code mapped the self-assessed level (Beginner/
 * Intermediate/Advanced) onto users.level — the XP level — so an "Advanced"
 * user with 0 XP showed level 3. Onboarding now stores the answer as
 * onboarding.selfAssessedLevel; this script recomputes `level` from `xp` for
 * every user and, where the stored level was higher than XP allows, records
 * the original answer as selfAssessedLevel.
 *
 *   npm run users:repair-levels            dry run — prints what would change
 *   npm run users:repair-levels -- --apply writes the changes
 */
require('dotenv').config();
const { db } = require('../config/firebase');
const { computeLevel } = require('../services/xpService');

const SELF_ASSESSED = { 1: 'Beginner', 2: 'Intermediate', 3: 'Advanced' };
const apply = process.argv.includes('--apply');

async function main() {
  const snap = await db.collection('users').get();
  let changed = 0;
  let batch = db.batch();
  let pending = 0;

  for (const doc of snap.docs) {
    const user = doc.data();
    const correct = computeLevel(user.xp || 0);
    if (user.level === correct) continue;

    const patch = { level: correct };
    const onboarding = user.onboarding || {};
    if (!onboarding.selfAssessedLevel && user.level > correct && SELF_ASSESSED[user.level]) {
      patch['onboarding.selfAssessedLevel'] = SELF_ASSESSED[user.level];
    }

    changed += 1;
    console.log(`${doc.id}: level ${user.level} -> ${correct} (xp ${user.xp || 0})`);
    if (apply) {
      batch.update(doc.ref, patch);
      pending += 1;
      if (pending === 450) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
  }

  if (apply && pending > 0) await batch.commit();
  console.log(`${changed} of ${snap.size} users ${apply ? 'repaired' : 'would change (dry run — pass --apply to write)'}.`);
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error(err);
    process.exit(1);
  }
);
