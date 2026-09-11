import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'youtube_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();
  static final _youtubeSignIn = GoogleSignIn(scopes: [
    'https://www.googleapis.com/auth/youtube.readonly',
    'https://www.googleapis.com/auth/youtube.force-ssl',
  ]);

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Email + password sign-in
  static Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Email + password registration
  static Future<UserCredential> signUpWithEmail(
      String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user?.updateDisplayName(name);
    return cred;
  }

  /// Google Sign-In
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-token',
          message: 'Google did not return an authentication token.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Google sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Connect a YouTube account for subscriptions, ratings, and comments.
  static Future<bool> connectYouTube() async {
    final account = await _youtubeSignIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) return false;
    YouTubeService.setAccessToken(token);
    return true;
  }

  /// Password reset email
  static Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _youtubeSignIn.signOut();
    YouTubeService.setAccessToken(null);
    await _auth.signOut();
  }

  /// Human-readable Firebase error messages
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'missing-google-token':
        return 'Google did not return a valid sign-in token.';
      case 'account-exists-with-different-credential':
        return 'This email already uses another sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
