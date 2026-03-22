const { auth } = require('../config/firebase');

/**
 * Creates a new Firebase Auth user.
 * @returns {{ uid, email }}
 */
async function createFirebaseUser(email, password, displayName) {
  const userRecord = await auth.createUser({
    email,
    password,
    displayName,
  });
  return { uid: userRecord.uid, email: userRecord.email };
}

/**
 * Generates a custom token for a given uid (used in register response).
 * Flutter can exchange this for an ID token via signInWithCustomToken.
 */
async function createCustomToken(uid) {
  return auth.createCustomToken(uid);
}

/**
 * Verifies an email/password credential via the Firebase Auth REST API.
 * Returns the user's idToken on success.
 *
 * NOTE: Firebase Admin SDK has no signInWithEmailAndPassword method —
 * that lives only in the client SDK. This service calls the REST endpoint
 * using the FIREBASE_API_KEY env variable.
 */
async function signInWithEmailAndPassword(email, password) {
  const axios = require('axios');
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!apiKey) {
    throw new Error('FIREBASE_API_KEY is not set in .env');
  }

  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  const response = await axios.post(url, {
    email,
    password,
    returnSecureToken: true,
  });

  return {
    idToken: response.data.idToken,
    refreshToken: response.data.refreshToken,
  };
}

module.exports = { createFirebaseUser, createCustomToken, signInWithEmailAndPassword, deleteFirebaseUser };

async function deleteFirebaseUser(uid) {
  await auth.deleteUser(uid);
}
