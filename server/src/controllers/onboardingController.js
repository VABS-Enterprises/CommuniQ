const { randomUUID } = require('crypto');
const { db } = require('../config/firebase');
const { FieldValue } = require('firebase-admin/firestore');
const { evaluateLearningAnswer, transcribeAudio } = require('../services/fastApiService');

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

/*
 * POST /onboarding/demo  (unauthenticated)
 *
 * Evaluates a short self-introduction typed by the user during onboarding.
 * Proxies to the AI server's /evaluate/learning endpoint so the user gets
 * real AI feedback before they even create an account — turning the teaser
 * screen into an instant conversion hook.
 *
 * Body: { userIntroduction: string }
 * Returns: { scores, overallScore, strengths, improvements, feedback }
 */
async function evaluateIntroDemo(req, res) {
  const { userIntroduction } = req.body;

  if (typeof userIntroduction !== 'string' || userIntroduction.trim().length < 10) {
    return res.status(400).json({ error: 'userIntroduction must be at least 10 characters.' });
  }
  if (userIntroduction.trim().length > 1000) {
    return res.status(400).json({ error: 'userIntroduction must be under 1000 characters.' });
  }

  const sessionId = `demo_${randomUUID()}`;

  console.log(`[OnboardingDemo] Evaluating intro demo — session=${sessionId} len=${userIntroduction.trim().length}`);

  try {
    const result = await evaluateLearningAnswer(
      sessionId,
      'Introduce yourself in a few sentences. Tell us your name, what you do or study, and why you want to improve your speaking skills.',
      userIntroduction.trim(),
      'self-introduction',
      'beginner',
      ['your name', 'what you do or study', 'why you want to improve speaking or communication'],
    );

    console.log(`[OnboardingDemo] ✅ Evaluation complete — session=${sessionId} overall=${result.overallScore}`);
    return res.status(200).json(result);
  } catch (err) {
    const status = err.statusCode || 502;
    console.error(`[OnboardingDemo] ❌ Evaluation failed — session=${sessionId}: ${err.message}`);
    return res.status(status).json({ error: err.message || 'Evaluation failed. Please try again.' });
  }
}

/*
 * POST /onboarding/transcribe  (unauthenticated, multipart)
 *
 * Accepts a voice recording from the onboarding demo screen and returns
 * a Whisper transcript so the user can review / edit before evaluating.
 *
 * Body: multipart/form-data  { audio: <file> }
 * Returns: { text: string }
 */
async function transcribeDemo(req, res) {
  if (!req.file) {
    return res.status(400).json({ error: 'No audio file uploaded.' });
  }

  const { buffer, originalname } = req.file;
  const filename = originalname || 'intro.wav';

  console.log(`[OnboardingTranscribe] Received ${filename} (${buffer.length} bytes)`);

  try {
    const text = await transcribeAudio(buffer, filename);
    console.log(`[OnboardingTranscribe] ✅ Transcript: "${text.slice(0, 80)}…"`);
    return res.status(200).json({ text });
  } catch (err) {
    const status = err.statusCode || 502;
    console.error(`[OnboardingTranscribe] ❌ ${err.message}`);
    return res.status(status).json({ error: err.message || 'Transcription failed.' });
  }
}

module.exports = { saveOnboarding, getOnboarding, evaluateIntroDemo, transcribeDemo };
