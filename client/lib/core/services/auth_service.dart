import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:communiq/core/constants/api_constants.dart';
import 'package:communiq/core/services/api_service.dart';
import 'package:communiq/core/services/profile_cache_service.dart';
import 'package:communiq/core/services/level_service.dart';

/// Thrown when the user dismisses the Google sign-in picker without selecting
/// an account. Callers should catch this and stay on the current screen.
class CancelledException implements Exception {
  const CancelledException();
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Stream<User?> get authStateChanges {
    debugPrint('[AuthService] authStateChanges stream requested');
    return _auth.authStateChanges();
  }

  static User? get currentUser {
    final user = _auth.currentUser;
    debugPrint('[AuthService] currentUser request → ${user?.uid ?? "null"}');
    return user;
  }

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
  /// profile via the Node backend.
  ///
  /// If the backend call fails (server down, network error, etc.) the Firebase
  /// Auth account is kept and the user proceeds to the home screen. The server's
  /// GET /auth/me endpoint has auto-recovery logic that creates the Firestore
  /// doc on first profile fetch, so no profile is ever permanently lost.
  ///
  /// A 409 from the backend means the Firestore doc already exists (idempotent
  /// retry) — this is treated as success, not an error.
  static Future<void> registerWithEmailPassword(
      String name, String email, String password) async {
    debugPrint('');
    debugPrint('[Email Auth] ── Starting registration ───────────────');
    debugPrint('[Email Auth] email=$email, name=$name');
    try {
      debugPrint('[Email Auth] Step 1: Creating Firebase user...');
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[Email Auth] Step 1: ✅ Firebase user created uid=${credential.user?.uid}');
      await credential.user?.updateDisplayName(name);

      // Step 2 is best-effort: if the backend is unreachable the user is still
      // authenticated via Firebase. GET /auth/me auto-creates the Firestore doc
      // on the first home-screen load (same resilience strategy as Google sign-in).
      debugPrint('[Email Auth] Step 2: Calling Node backend ${ApiConstants.authRegister}...');
      debugPrint('[Email Auth]   Server: ${ApiService.instance.dio.options.baseUrl}');
      try {
        await ApiService.post(ApiConstants.authRegister, body: {
          'name': name,
          'email': email,
        });
        debugPrint('[Email Auth] Step 2: ✅ Firestore profile created');
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          // User doc already exists — idempotent retry, treat as success.
          debugPrint('[Email Auth] Step 2: ✅ User already registered (409 — idempotent)');
        } else {
          // Backend unreachable or server error — profile will be auto-created
          // by GET /auth/me when the home screen loads.
          debugPrint('[Email Auth] Step 2: ⚠️  Backend unreachable — '
              'profile will be created on first home load. ($e)');
        }
      } catch (e) {
        debugPrint('[Email Auth] Step 2: ⚠️  Backend call failed — '
            'profile will be created on first home load. ($e)');
      }

      debugPrint('[Email Auth] ── Registration complete ✅ ────────────');
      debugPrint('');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Email Auth] ❌ FirebaseAuthException code=${e.code}: ${e.message}');
      throw _handleFirebaseError(e);
    } catch (e) {
      debugPrint('[Email Auth] ❌ Unexpected error: $e');
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
        debugPrint('[Google Auth] Step 2: ❌ TOKENS ARE NULL');
        debugPrint('[Google Auth]   → The signing certificate of THIS build is not');
        debugPrint('[Google Auth]   → registered in Firebase for com.vabs.communiq.');
        debugPrint('[Google Auth]   → Print the one actually in use with:');
        debugPrint('[Google Auth]   →   ./gradlew signingReport');
        debugPrint('[Google Auth]   → then add it under Firebase Console →');
        debugPrint('[Google Auth]   →   Project Settings → Android app → Add fingerprint,');
        debugPrint('[Google Auth]   → and re-download google-services.json.');
        throw Exception(
            "This build's signing certificate isn't registered in Firebase. "
            'Run ./gradlew signingReport and add that SHA-1 to the Firebase '
            'console.');
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
      throw _handleFirebaseError(e);
    } on PlatformException catch (e) {
      debugPrint('[Google Auth] ❌ PlatformException');
      debugPrint('[Google Auth]   code:    ${e.code}');
      debugPrint('[Google Auth]   message: ${e.message}');
      throw googleSignInErrorFor(e);
    } catch (e) {
      if (e is CancelledException) rethrow;
      debugPrint('[Google Auth] ❌ Unexpected error: $e');
      throw Exception('Google Sign-In failed. Please try again.');
    }
  }

  /// Turns a Google Play Services failure into something the user can act on.
  ///
  /// Every one of these used to collapse into "Google Sign-In failed. Please
  /// try again." — which is wrong for most of them: a device with no network,
  /// or a build whose certificate isn't registered, will fail identically on
  /// every retry, so "try again" sends the user in a loop and hides the cause.
  /// The GMS status code is the only thing that distinguishes them, and it is
  /// carried in the message as "ApiException: <code>".
  @visibleForTesting
  static Exception googleSignInErrorFor(PlatformException e) {
    final detail = '${e.code} ${e.message ?? ''}';
    final status = RegExp(r'ApiException:\s*(\d+)').firstMatch(detail)?.group(1);

    // The picker was dismissed — not an error worth showing.
    if (status == '12501' || e.code == 'sign_in_canceled') {
      return const CancelledException();
    }

    switch (status) {
      case '7': // NETWORK_ERROR
        return Exception(
            "Can't reach Google — check your internet connection.");
      case '10': // DEVELOPER_ERROR — signing cert / OAuth client mismatch
        return Exception(
            "This build isn't registered for Google Sign-In. Run "
            './gradlew signingReport and add that SHA-1 to the Firebase '
            'console.');
      case '12502': // SIGN_IN_CURRENTLY_IN_PROGRESS
        return Exception('A sign-in is already in progress.');
      case '12500': // SIGN_IN_FAILED — usually a Play Services problem
        return Exception(
            'Google Sign-In could not complete. Make sure Google Play '
            'services is up to date.');
      case '8': // INTERNAL_ERROR
        return Exception('Google had an internal error. Try again shortly.');
    }

    if (e.code == 'network_error') {
      return Exception(
          "Can't reach Google — check your internet connection.");
    }
    return Exception('Google Sign-In failed. Please try again.');
  }

  /// Signs the user out from both Firebase and Google, and clears the local
  /// profile cache so a stale profile is never shown to the next user.
  static Future<void> signOut() async {
    debugPrint('[AuthService] signOut →');
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
        ProfileCacheService.clear(),
        LevelService.instance.clearProgress(),
      ]);
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
