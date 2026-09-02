const firestoreService = require('../services/firestoreService');
const { updateUser, getUserById } = firestoreService;
const { FieldValue } = require('firebase-admin/firestore');
const fastApiService = require('../services/fastApiService');

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
async function updateTrainingConsent(req, res) {
  const userId = req.uid;
  const { optedIn } = req.body;

  if (typeof optedIn !== 'boolean') {
    return res.status(400).json({ error: 'optedIn must be a boolean' });
  }

  try {
    await updateUser(userId, {
      'trainingConsent.optedIn': optedIn,
      'trainingConsent.updatedAt': FieldValue.serverTimestamp(),
    });
    return res.status(200).json({ trainingConsent: { optedIn } });
  } catch (err) {
    console.error('updateTrainingConsent error:', err.message);
    return res.status(500).json({ error: 'Could not update training consent' });
  }
}

// GET /user/evaluation-profile
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

async function saveVisualReport(req, res) {
  try {
    const userId = req.uid;
    const reportData = req.body;

    // Call fastApiService to query Python ai-server Groq LLM model
    try {
      const aiResponse = await fastApiService.evaluateVisual({
        eyeContactPercentage: reportData.eyeContactPercentage || 0,
        gazeStabilityPercentage: reportData.gazeStabilityPercentage || 0,
        spineAlignmentPercentage: reportData.spineAlignmentPercentage || 0,
        shoulderSymmetryPercentage: reportData.shoulderSymmetryPercentage || 0,
        chestOpennessPercentage: reportData.chestOpennessPercentage || 0,
        headTiltStabilityPercentage: reportData.headTiltStabilityPercentage || 0,
        handMovementPercentage: reportData.handMovementPercentage || 0,
        overallPostureScore: reportData.overallPostureScore || 0,
      });

      if (aiResponse && Array.isArray(aiResponse.insights) && aiResponse.insights.length > 0) {
        reportData.insights = aiResponse.insights;
      }
    } catch (aiErr) {
      console.warn('[saveVisualReport] AI evaluation fallback used:', aiErr.message);
    }

    const saved = await firestoreService.saveVisualReport(userId, reportData);
    return res.status(201).json({ success: true, report: saved, insights: reportData.insights });
  } catch (err) {
    console.error('saveVisualReport error:', err.message);
    return res.status(500).json({ error: 'Could not save visual report to Firestore' });
  }
}

async function getVisualReports(req, res) {
  try {
    const userId = req.uid;
    const reports = await firestoreService.getUserVisualReports(userId);
    return res.status(200).json({ reports });
  } catch (err) {
    console.error('getVisualReports error:', err.message);
    return res.status(500).json({ error: 'Could not fetch visual reports' });
  }
}

module.exports = {
  getProfile,
  updateProfile,
  updateTrainingConsent,
  getEvaluationProfile,
  saveVisualReport,
  getVisualReports,
};
