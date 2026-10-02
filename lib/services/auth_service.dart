import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn.instance;
  static const String _kLoggedInKey = 'is_logged_in';
  static const String _kLoggedInEmailKey = 'logged_in_email';

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Check whether an authenticated session exists
  static Future<bool> isUserLoggedIn() async {
    if (_auth.currentUser != null) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kLoggedInKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mark session active in local preferences
  static Future<void> markUserLoggedIn([String? email]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLoggedInKey, true);
      if (email != null && email.isNotEmpty) {
        await prefs.setString(_kLoggedInEmailKey, email);
      }
    } catch (_) {}
  }

  /// Initialize Google Sign-In (must be called once at app start)
  static Future<void> initGoogleSignIn() async {
    await _googleSignIn.initialize();
  }

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
      final googleUser = await _googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Google sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Connect a YouTube account for subscriptions, ratings, and comments.
  static Future<bool> connectYouTube() async {
    try {
      final account = await _googleSignIn.authenticate(
        scopeHint: [
          'https://www.googleapis.com/auth/youtube.readonly',
          'https://www.googleapis.com/auth/youtube.force-ssl',
        ],
      );
      final authClient = account.authorizationClient;
      final authorization = await authClient.authorizeScopes([
        'https://www.googleapis.com/auth/youtube.readonly',
        'https://www.googleapis.com/auth/youtube.force-ssl',
      ]);
      final token = authorization.accessToken;
      if (token.isEmpty) return false;
      YouTubeService.setAccessToken(token);
      return true;
    } catch (e) {
      debugPrint('YouTube connect error: $e');
      return false;
    }
  }

  /// Password reset email
  static Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out note: $e');
    }
    YouTubeService.setAccessToken(null);
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('FirebaseAuth sign-out note: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLoggedInKey, false);
      await prefs.remove(_kLoggedInEmailKey);
    } catch (e) {
      debugPrint('Prefs sign-out note: $e');
    }
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
