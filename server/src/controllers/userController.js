const { updateUser, getUserById } = require('../services/firestoreService');

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

module.exports = { updateProfile };
