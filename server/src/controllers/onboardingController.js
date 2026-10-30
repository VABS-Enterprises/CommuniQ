const { randomUUID } = require('crypto');
const { db } = require('../config/firebase');
const { publicError } = require('../utils/publicError');
const { FieldValue } = require('firebase-admin/firestore');
const { evaluateLearningAnswer, transcribeAudio } = require('../services/fastApiService');
const { createUserDoc, createGoogleUserDoc } = require('../models/userModel');

const SELF_ASSESSED_LEVELS = new Set(['Beginner', 'Intermediate', 'Advanced']);

function normaliseLevel(level) {
  if (typeof level !== 'string' || level.length === 0) return null;
  const normalised = level.charAt(0).toUpperCase() + level.slice(1).toLowerCase();
  return SELF_ASSESSED_LEVELS.has(normalised) ? normalised : null;
}

/*
 * POST /onboarding
 *
 * Merges onboarding answers into users/{uid}. Safe to call multiple times.
 *
 * The self-assessed level is stored as onboarding.selfAssessedLevel. It used to
 * overwrite users.level — the XP level — which unlocked content an XP-0 user
 * had not earned and was then silently undone by the first session end.
 *
 * This can race /auth/register on first sign-in, so if the user document does
 * not exist yet it is created with full defaults rather than as a bare
 * onboarding-only document.
 */
async function saveOnboarding(req, res) {
  const uid = req.uid;
  const { contexts, challenges, speakingStyle, speakingNote, level, primaryGoal, commitmentDays } =
    req.body;

  console.log(`[Onboarding] POST /onboarding uid=${uid}`);

  if (!Array.isArray(contexts) || contexts.length === 0) {
    return res.status(400).json({ error: 'contexts must be a non-empty array' });
  }
  if (!Array.isArray(challenges) || challenges.length === 0) {
    return res.status(400).json({ error: 'challenges must be a non-empty array' });
  }

  try {
    const selfAssessedLevel = normaliseLevel(level);
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
        ...(selfAssessedLevel && { selfAssessedLevel }),
        completedAt: FieldValue.serverTimestamp(),
      },
      onboardingCompleted: true,
    };

    const ref = db.collection('users').doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists) {
        tx.set(ref, onboardingFields, { merge: true });
      } else {
        const base = req.name
          ? createGoogleUserDoc(uid, { email: req.email || '', name: req.name, photoURL: req.picture })
          : createUserDoc(uid, { email: req.email || '', name: req.email ? req.email.split('@')[0] : 'User' });
        tx.set(ref, { ...base, ...onboardingFields });
      }
    });

    console.log(`[Onboarding] ✅ users/${uid} updated with onboarding data`);

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
    return res.status(status).json({ error: publicError(err, 'Evaluation failed. Please try again.') });
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
    console.log(`[OnboardingTranscribe] ✅ Transcribed ${text.length} chars`);
    return res.status(200).json({ text });
  } catch (err) {
    const status = err.statusCode || 502;
    console.error(`[OnboardingTranscribe] ❌ ${err.message}`);
    return res.status(status).json({ error: publicError(err, 'Transcription failed.') });
  }
}

module.exports = { saveOnboarding, getOnboarding, evaluateIntroDemo, transcribeDemo };
