const { updateUser, getUserById } = require('../services/firestoreService');

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
  const { name, learning_progress } = req.body;

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

  if (learning_progress !== undefined) {
    if (!Array.isArray(learning_progress)) {
      return res.status(400).json({ error: 'learning_progress must be an array' });
    }
    updates.learning_progress = learning_progress;
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

module.exports = { getProfile, updateProfile };
