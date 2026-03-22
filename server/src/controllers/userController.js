const { updateUser, getUserById } = require('../services/firestoreService');

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

  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    return res.status(400).json({ error: 'A valid name is required' });
  }

  try {
    await updateUser(userId, { name: name.trim() });
    const user = await getUserById(userId);
    return res.status(200).json({ user });
  } catch (err) {
    console.error('updateProfile error:', err.message);
    return res.status(500).json({ error: 'Could not update profile' });
  }
}

module.exports = { getProfile, updateProfile };
