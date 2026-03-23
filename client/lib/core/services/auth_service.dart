import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:communiq/core/services/api_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream to listen to Auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if someone is already logged in
  static User? get currentUser => _auth.currentUser;

  /// Logs the user in with Email and Password
  static Future<void> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Backend automatically maps this because the token gets generated
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Registers a new user with Email and Password, and syncs to backend
  static Future<void> registerWithEmailPassword(String name, String email, String password) async {
    try {
      // 1. Create purely in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Update display name in Firebase 
      await credential.user?.updateDisplayName(name);

      // 2. Call our Node backend to generate the Firestore entry securely
      await ApiService.post('/auth/register', body: {
        'name': name,
        'email': email,
      });

    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      // If node fails, user is technically logged in via firebase. We must rollback here ideally.
      // But for prototype: throw error to UI
      throw Exception('Server error: $e');
    }
  }

  /// Signs the user in with Google and syncs to backend 
  static Future<void> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      // Get the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase 
      await _auth.signInWithCredential(credential);

      // After successful Firebase sign-in, fire an API call to Node to create/update Firestore!
      await ApiService.post('/auth/google');
      
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Signs the user out locally
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  
  // Pretty up firebase random errors for the UI toast messages
  static Exception _handleFirebaseError(FirebaseAuthException e) {
    if (e.code == 'user-not-found') return Exception('No account found for that email.');
    if (e.code == 'wrong-password') return Exception('Wrong password provided.');
    if (e.code == 'email-already-in-use') return Exception('Account already exists for that email.');
    if (e.code == 'weak-password') return Exception('The password provided is too weak.');
    return Exception(e.message ?? 'Unknown auth error occurred.');
  }
}
