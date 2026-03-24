import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';

/// Thrown when the user dismisses the Google sign-in picker without selecting
/// an account. Callers should catch this and stay on the current screen.
class CancelledException implements Exception {
  const CancelledException();
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  /// Signs the user in with email and password.
  static Future<void> signInWithEmailPassword(
      String email, String password) async {
    debugPrint('[AuthService] signInWithEmailPassword → email=$email');
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[AuthService] signInWithEmailPassword ✓');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] signInWithEmailPassword ✗ code=${e.code}: ${e.message}');
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthService] signInWithEmailPassword ✗ unexpected: $e');
      throw Exception('Sign-in failed. Please try again.');
    }
  }

  /// Registers a new user with email and password, then creates the Firestore
  /// profile via the Node backend. If the backend call fails the Firebase Auth
  /// account is deleted so there is no partial state.
  static Future<void> registerWithEmailPassword(
      String name, String email, String password) async {
    debugPrint('');
    debugPrint('[Email Auth] ── Starting registration ───────────────');
    debugPrint('[Email Auth] email=$email, name=$name');
    UserCredential? credential;
    try {
      debugPrint('[Email Auth] Step 1: Creating Firebase user...');
      credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[Email Auth] Step 1: ✅ Firebase user created uid=${credential.user?.uid}');
      await credential.user?.updateDisplayName(name);

      debugPrint('[Email Auth] Step 2: Calling Node backend ${ApiConstants.authRegister}...');
      debugPrint('[Email Auth]   ⚠️  If on physical device, ensure server URL is set correctly!');
      debugPrint('[Email Auth]   Run: flutter run --dart-define=SERVER_URL=http://YOUR_IP:3000');
      await ApiService.post(ApiConstants.authRegister, body: {
        'name': name,
        'email': email,
      });
      debugPrint('[Email Auth] Step 2: ✅ Firestore profile created');
      debugPrint('[Email Auth] ── Registration complete ✅ ────────────');
      debugPrint('');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Email Auth] ❌ FirebaseAuthException code=${e.code}: ${e.message}');
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[Email Auth] ❌ Backend call failed: $e');
      debugPrint('[Email Auth]   Rolling back Firebase user...');
      // Roll back the Firebase account so there is no orphaned auth record
      // without a Firestore profile.
      try {
        await credential?.user?.delete();
        debugPrint('[Email Auth]   Rollback ✅ Firebase user deleted');
      } catch (deleteErr) {
        debugPrint('[Email Auth]   Rollback ❌ Could not delete Firebase user: $deleteErr');
      }
      throw Exception('Registration failed. Please try again.');
    }
  }

  /// Signs the user in with Google. Throws [CancelledException] if the user
  /// dismisses the picker, so callers can stay on the current screen without
  /// navigating.
  static Future<void> signInWithGoogle() async {
    debugPrint('');
    debugPrint('[Google Auth] ── Starting sign-in flow ──────────────');
    try {
      debugPrint('[Google Auth] Step 1: Opening Google account picker...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[Google Auth] Step 1: ⚠️  User cancelled the picker');
        throw const CancelledException();
      }
      debugPrint('[Google Auth] Step 1: ✅ User selected: ${googleUser.email}');

      debugPrint('[Google Auth] Step 2: Fetching auth tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      debugPrint('[Google Auth] Step 2: Got tokens — '
          'accessToken: ${accessToken != null}, idToken: ${idToken != null}');

      if (accessToken == null || idToken == null) {
        debugPrint('[Google Auth] Step 2: ❌ TOKENS ARE NULL!');
        debugPrint('[Google Auth]   → This means SHA-1 fingerprint is NOT registered');
        debugPrint('[Google Auth]   → in Firebase Console for package com.vabs.communiq');
        debugPrint('[Google Auth]   → Fix: Firebase Console → Project Settings →');
        debugPrint('[Google Auth]   →      Android app → Add fingerprint');
        debugPrint('[Google Auth]   →      SHA-1: 30:D5:49:BA:E5:8C:F1:F6:4D:06:00:22:7C:92:33:E1:69:89:AF:3E');
        throw Exception(
            'Google authentication tokens missing. SHA-1 fingerprint not registered in Firebase.');
      }

      debugPrint('[Google Auth] Step 3: Signing in to Firebase...');
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('[Google Auth] Step 3: ✅ Firebase sign-in success — '
          'uid=${userCredential.user?.uid}, email=${userCredential.user?.email}');

      // Step 4 is fire-and-forget: if the backend is unreachable the user is
      // still authenticated via Firebase. The GET /auth/me auto-recovery will
      // create the Firestore doc on the first home-screen load.
      debugPrint('[Google Auth] Step 4: Syncing Firestore profile...');
      try {
        await ApiService.post(ApiConstants.authGoogle);
        debugPrint('[Google Auth] Step 4: ✅ Profile synced');
      } catch (apiErr) {
        debugPrint('[Google Auth] Step 4: ⚠️  Backend unreachable — '
            'profile will be created on first home load. ($apiErr)');
      }
      debugPrint('[Google Auth] ── Sign-in complete ✅ ─────────────────');
      debugPrint('');
    } on CancelledException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Google Auth] ❌ FirebaseAuthException');
      debugPrint('[Google Auth]   code:    ${e.code}');
      debugPrint('[Google Auth]   message: ${e.message}');
      if (e.code == 'sign_in_failed' || e.code == 'sign-in-failed') {
        debugPrint('[Google Auth]   CAUSE: Missing SHA-1 in Firebase Console');
        debugPrint('[Google Auth]   SHA-1: 30:D5:49:BA:E5:8C:F1:F6:4D:06:00:22:7C:92:33:E1:69:89:AF:3E');
      }
      throw _handleFirebaseError(e);
    } catch (e) {
      if (e is CancelledException) rethrow;
      debugPrint('[Google Auth] ❌ Unexpected error: $e');
      throw Exception('Google Sign-In failed. Please try again.');
    }
  }

  /// Signs the user out from both Firebase and Google.
  static Future<void> signOut() async {
    debugPrint('[AuthService] signOut →');
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('[AuthService] signOut ✓');
    } catch (e) {
      debugPrint('[AuthService] signOut ✗ $e');
    }
  }

  /// Sends a password reset email to [email].
  static Future<void> sendPasswordReset(String email) async {
    debugPrint('[AuthService] sendPasswordReset → email=$email');
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('[AuthService] sendPasswordReset ✓');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] sendPasswordReset ✗ code=${e.code}: ${e.message}');
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[AuthService] sendPasswordReset ✗ $e');
      throw Exception('Could not send reset email. Please try again.');
    }
  }

  static Exception _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found for that email.');
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Incorrect email or password.');
      case 'email-already-in-use':
        return Exception('An account already exists for that email.');
      case 'weak-password':
        return Exception('Password must be at least 6 characters.');
      case 'invalid-email':
        return Exception('Please enter a valid email address.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later.');
      case 'network-request-failed':
        return Exception('Network error. Check your connection and try again.');
      case 'user-disabled':
        return Exception('This account has been disabled. Contact support.');
      case 'operation-not-allowed':
        return Exception('Sign-in method not enabled. Contact support.');
      case 'sign_in_failed':
      case 'sign-in-failed':
        return Exception(
            'Google Sign-In failed. Ensure SHA-1 is registered in Firebase.');
      default:
        return Exception(
            e.message ?? 'Authentication failed. Please try again.');
    }
  }
}
