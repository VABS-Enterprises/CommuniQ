const { updateUser, getUserById } = require('../services/firestoreService');
const { FieldValue } = require('firebase-admin/firestore');

const MAX_NAME_LENGTH = 100;

// GET /user/profile
async function getProfile(req, res) {
  try {
    const user = await getUserById(req.uid);
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.status(200).json({ user });
  } catch (err) {
    console.error('getProfile error:', err.message);
    return res.status(500).json({ error: 'Could not fetch profile' });
  }
}

// PATCH /user/profile
// Note: the legacy `learning_progress` (array) field this endpoint used to accept
// was removed — it collided in name with `learningProgress` (object), the
// server-authoritative field now owned exclusively by the learning module
// (routes/learning.js). The client no longer sends it (grading moved server-side).
async function updateProfile(req, res) {
  const userId = req.uid;
  const { name } = req.body;

  const updates = {};

  if (name !== undefined) {
    if (typeof name !== 'string' || name.trim().length === 0) {
      return res.status(400).json({ error: 'A valid name is required' });
    }
    if (name.trim().length > MAX_NAME_LENGTH) {
      return res.status(400).json({ error: `name must be at most ${MAX_NAME_LENGTH} characters` });
    }
    updates.name = name.trim();
  }

  if (Object.keys(updates).length === 0) {
    return res.status(400).json({ error: 'No valid fields to update' });
  }

  try {
    await updateUser(userId, updates);
    const user = await getUserById(userId);
    return res.status(200).json({ user });
  } catch (err) {
    console.error('updateProfile error:', err.message);
    return res.status(500).json({ error: 'Could not update profile' });
  }
}

// PATCH /user/training-consent
// Data-governance / opt-out control (paper §3.6): lets a user opt in/out of
// their session data being used for future model training. Non-blocking —
// opting out does not remove access to any platform feature.
async function updateTrainingConsent(req, res) {
  const userId = req.uid;
  const { optedIn } = req.body;

  if (typeof optedIn !== 'boolean') {
    return res.status(400).json({ error: 'optedIn (boolean) is required' });
  }

  try {
    await updateUser(userId, {
      trainingConsent: { optedIn, updatedAt: FieldValue.serverTimestamp() },
    });
    return res.status(200).json({ trainingConsent: { optedIn } });
  } catch (err) {
    console.error('updateTrainingConsent error:', err.message);
    return res.status(500).json({ error: 'Could not update training consent' });
  }
}

// GET /user/evaluation-profile
// Returns the calling user's own longitudinal evaluation-model state
// (skillHistory, scenario category counts) plus their most recent report's
// adaptive block — for a future "why did I get this score" transparency UI,
// and for manual QA of the self-learning evaluation model.
async function getEvaluationProfile(req, res) {
  try {
    const user = await getUserById(req.uid);
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.status(200).json({
      skillHistory: user.skillHistory || {},
      scenarioCategoryCounts: user.scenarioCategoryCounts || {},
      trainingConsent: user.trainingConsent || { optedIn: true },
    });
  } catch (err) {
    console.error('getEvaluationProfile error:', err.message);
    return res.status(500).json({ error: 'Could not fetch evaluation profile' });
  }
}

module.exports = { getProfile, updateProfile, updateTrainingConsent, getEvaluationProfile };
