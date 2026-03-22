const { auth } = require('../config/firebase');

/**
 * Deletes a Firebase Auth account by uid.
 * Used by DELETE /auth/account — the only auth operation
 * that cannot be done from Flutter's client SDK safely,
 * because it must be preceded by a Firestore batch delete.
 */
async function deleteFirebaseUser(uid) {
  await auth.deleteUser(uid);
}

module.exports = { deleteFirebaseUser };
