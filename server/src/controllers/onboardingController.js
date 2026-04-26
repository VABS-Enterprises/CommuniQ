const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');

const LEVEL_MAP = { Beginner: 1, Intermediate: 2, Advanced: 3 };

/*
 * POST /onboarding
 *
 * Merges onboarding answers into the existing users/{uid} document.
 * Uses merge:true so existing fields (name, email, streak, etc.) are preserved.
 * Safe to call multiple times — idempotent upsert.
 */
async function saveOnboarding(req, res) {
  const uid = req.uid;
  const { contexts, challenges, speakingStyle, speakingNote, level, primaryGoal, commitmentDays } =
    req.body;

  console.log('\n[Onboarding] ── Incoming POST /onboarding ──────────────────');
  console.log(`[Onboarding]   uid            : ${uid}`);
  console.log(`[Onboarding]   contexts       : ${JSON.stringify(contexts)}`);
  console.log(`[Onboarding]   challenges     : ${JSON.stringify(challenges)}`);
  console.log(`[Onboarding]   speakingStyle  : ${speakingStyle ?? '—'}`);
  console.log(`[Onboarding]   speakingNote   : ${speakingNote ?? '—'}`);
  console.log(`[Onboarding]   level          : ${level ?? '—'}`);
  console.log(`[Onboarding]   primaryGoal    : ${primaryGoal ?? '—'}`);
  console.log(`[Onboarding]   commitmentDays : ${commitmentDays ?? '—'}`);
  console.log('[Onboarding] ────────────────────────────────────────────────');

  if (!Array.isArray(contexts) || contexts.length === 0) {
    console.warn('[Onboarding] ⚠️  Validation failed: contexts missing');
    return res.status(400).json({ error: 'contexts must be a non-empty array' });
  }
  if (!Array.isArray(challenges) || challenges.length === 0) {
    console.warn('[Onboarding] ⚠️  Validation failed: challenges missing');
    return res.status(400).json({ error: 'challenges must be a non-empty array' });
  }

  try {
    const onboardingFields = {
      onboarding: {
        contexts: contexts.filter((c) => typeof c === 'string'),
        challenges: challenges.filter((c) => typeof c === 'string'),
        ...(typeof speakingStyle === 'string' && { speakingStyle }),
        ...(typeof speakingNote === 'string' && speakingNote.trim() && {
          speakingNote: speakingNote.trim(),
        }),
        ...(typeof primaryGoal === 'string' && { primaryGoal }),
        ...([2, 3, 5].includes(commitmentDays) && { commitmentDays }),
        completedAt: FieldValue.serverTimestamp(),
      },
      onboardingCompleted: true,
      ...(typeof level === 'string' && (() => {
        const normalised = level.charAt(0).toUpperCase() + level.slice(1).toLowerCase();
        return LEVEL_MAP[normalised];
      })() && {
        level: LEVEL_MAP[level.charAt(0).toUpperCase() + level.slice(1).toLowerCase()],
      }),
    };

    console.log(`[Onboarding] Writing onboarding data → users/${uid}`);

    await db.collection('users').doc(uid).set(onboardingFields, { merge: true });

    console.log(`[Onboarding] ✅ users/${uid} updated with onboarding data\n`);

    return res.status(201).json({ uid, ...onboardingFields });
  } catch (err) {
    console.error('[Onboarding] ❌ saveOnboarding error:', err.message);
    return res.status(500).json({ error: 'Failed to save onboarding data' });
  }
}

/*
 * GET /onboarding
 *
 * Returns the onboarding sub-object from the users/{uid} document.
 */
async function getOnboarding(req, res) {
  const uid = req.uid;
  console.log(`[Onboarding] GET /onboarding — uid: ${uid}`);
  try {
    const snap = await db.collection('users').doc(uid).get();
    if (!snap.exists || !snap.data().onboarding) {
      console.log(`[Onboarding] No onboarding data found for uid: ${uid}`);
      return res.status(404).json({ error: 'No onboarding profile found' });
    }
    console.log(`[Onboarding] ✅ Onboarding data found for uid: ${uid}`);
    return res.status(200).json({ onboarding: snap.data().onboarding });
  } catch (err) {
    console.error('[Onboarding] ❌ getOnboarding error:', err.message);
    return res.status(500).json({ error: 'Failed to fetch onboarding data' });
  }
}

module.exports = { saveOnboarding, getOnboarding };
