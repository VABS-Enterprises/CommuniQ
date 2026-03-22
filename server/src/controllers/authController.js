const { deleteFirebaseUser } = require('../services/authService');
const { createUser, getUserById, deleteUserData } = require('../services/firestoreService');

const MAX_NAME_LENGTH = 100;

/*
 * POST /auth/register
 *
 * Flutter's responsibility BEFORE calling this:
 *   FirebaseAuth.instance.createUserWithEmailAndPassword(email, password)
 *   → Flutter gets an ID token and sends it as Authorization: Bearer <token>
 *
 * Node's responsibility HERE:
 *   - Verify the token (done by verifyToken middleware → req.uid, req.email)
 *   - Create the Firestore user document with app-specific defaults
 *     (xp, level, streak, badges, isPremium — Flutter can never write these)
 */
async function register(req, res) {
  const { name } = req.body;
  const uid = req.uid;
  const email = req.email;

  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    return res.status(400).json({ error: 'name is required' });
  }
  // Security4: cap name length to prevent storing massive payloads
  if (name.trim().length > MAX_NAME_LENGTH) {
    return res.status(400).json({ error: `name must be at most ${MAX_NAME_LENGTH} characters` });
  }

  try {
    // Robustness3: prevent silently overwriting an existing user document on network retries
    const existing = await getUserById(uid);
    if (existing) {
      return res.status(409).json({ error: 'User already registered' });
    }

    const user = await createUser(uid, { email, name: name.trim() });
    return res.status(201).json({ user });
  } catch (err) {
    console.error('register error:', err.message);
    return res.status(500).json({ error: 'Registration failed' });
  }
}

/*
 * DELETE /auth/account
 *
 * Cannot be Flutter-only because:
 *   1. Firestore batch deletion (sessions, reports, user doc) requires Admin SDK
 *   2. Firestore data must be cleaned up BEFORE the Auth account is removed
 */
async function deleteAccount(req, res) {
  const uid = req.uid;

  try {
    await deleteUserData(uid);
    await deleteFirebaseUser(uid);
    return res.status(200).json({ message: 'Account deleted successfully' });
  } catch (err) {
    console.error('deleteAccount error:', err.message);
    return res.status(500).json({ error: 'Could not delete account' });
  }
}

module.exports = { register, deleteAccount };
