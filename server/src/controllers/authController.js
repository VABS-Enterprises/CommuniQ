const { createFirebaseUser, createCustomToken, signInWithEmailAndPassword, deleteFirebaseUser } = require('../services/authService');
const { createUser, getUserById, deleteUserData } = require('../services/firestoreService');

async function register(req, res) {
  const { name, email, password } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({ error: 'name, email, and password are required' });
  }

  try {
    const { uid } = await createFirebaseUser(email, password, name);
    const user = await createUser(uid, { email, name });
    const token = await createCustomToken(uid);
    return res.status(201).json({ uid, token, user });
  } catch (err) {
    console.error('register error:', err.message);
    if (err.code === 'auth/email-already-exists') {
      return res.status(409).json({ error: 'Email already in use' });
    }
    return res.status(500).json({ error: 'Registration failed' });
  }
}

async function login(req, res) {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const { idToken } = await signInWithEmailAndPassword(email, password);

    // Decode without re-verifying to get uid (already trusted from Firebase REST)
    const { auth } = require('../config/firebase');
    const decoded = await auth.verifyIdToken(idToken);
    const user = await getUserById(decoded.uid);

    return res.status(200).json({ token: idToken, user });
  } catch (err) {
    console.error('login error:', err.message);
    if (err.response?.status === 400) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    return res.status(500).json({ error: 'Login failed' });
  }
}

async function me(req, res) {
  try {
    const user = await getUserById(req.uid);
    if (!user) return res.status(404).json({ error: 'User not found' });
    return res.status(200).json({ user });
  } catch (err) {
    console.error('me error:', err.message);
    return res.status(500).json({ error: 'Could not fetch user' });
  }
}

module.exports = { register, login, me, deleteAccount };

async function deleteAccount(req, res) {
  const uid = req.uid;

  try {
    // Delete all Firestore data first (sessions, reports, user doc)
    await deleteUserData(uid);
    // Delete the Firebase Auth account
    await deleteFirebaseUser(uid);
    return res.status(200).json({ message: 'Account deleted successfully' });
  } catch (err) {
    console.error('deleteAccount error:', err.message);
    return res.status(500).json({ error: 'Could not delete account' });
  }
}
