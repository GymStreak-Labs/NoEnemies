import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thin wrapper over [FirebaseAuth] that owns social + email sign-in flows.
///
/// Phase 1A responsibilities only: sign in, sign out, auth state stream.
/// Firestore profile linking lands in Phase 1B (the repository layer); AI
/// mentor wiring lands in Phase 1C.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // google_sign_in 7.x requires an explicit one-time initialize() before any
  // authenticate() / signOut() call. We guard with a future so concurrent
  // callers all wait on the same init.
  Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= _googleSignIn.initialize();
  }

  /// Currently signed-in user, or `null` if signed out.
  User? get currentUser => _auth.currentUser;

  /// Stream of [User] as auth state changes (sign-in, sign-out, token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Apple
  // ---------------------------------------------------------------------------

  /// Sign in with Apple. Apple Sign-In is mandatory on iOS because we ship
  /// Google / Email (App Store Review Guideline 4.8).
  Future<User> signInWithApple() async {
    // Nonce prevents replay attacks.
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: 'Apple Sign-In returned no user.',
      );
    }

    // Apple only returns the full name on the VERY first sign-in. Cache it on
    // the Firebase profile so we can show it later.
    if (appleCredential.givenName != null ||
        appleCredential.familyName != null) {
      final displayName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      if (displayName.isNotEmpty && (user.displayName ?? '').isEmpty) {
        await user.updateDisplayName(displayName);
      }
    }

    return user;
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  /// Sign in with Google via the native picker. Returns the Firebase [User].
  ///
  /// Throws [FirebaseAuthException] on failure; returns `null` only if the
  /// user cancelled the picker (we rethrow as an exception so callers can
  /// show a consistent error UI).
  Future<User> signInWithGoogle() async {
    // google_sign_in 7.x: initialize-once singleton, then authenticate().
    await _ensureGoogleInitialized();

    // Clear any previous Google session so the picker always appears.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore — no prior session.
    }

    if (!_googleSignIn.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'google-sign-in-unsupported',
        message: 'Google Sign-In is not supported on this platform.',
      );
    }

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      // Surface user-cancellation as the same code the UI already handles.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }
      rethrow;
    }

    final googleAuth = googleUser.authentication;
    // v7 only exposes idToken on authentication (accessToken moved to the
    // authorizationClient + scopes flow). The idToken is sufficient for
    // Firebase Auth credential exchange.
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google Sign-In returned no user.',
      );
    }
    return user;
  }

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  /// Sign in an existing user with email + password.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'email-sign-in-failed',
        message: 'Email sign-in returned no user.',
      );
    }
    return user;
  }

  /// Create a new user with email + password.
  Future<User> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'email-sign-up-failed',
        message: 'Email sign-up returned no user.',
      );
    }
    return user;
  }

  /// Send a password-reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Sign out of Firebase Auth AND any active social providers.
  Future<void> signOut() async {
    try {
      // v7 requires initialize() before signOut(); only attempt if we've
      // kicked the init off (i.e. the user has actually Google-auth'd).
      if (_googleInitFuture != null) {
        await _googleInitFuture;
        await _googleSignIn.signOut();
      }
    } catch (e) {
      // Google sign-out can fail silently if the user never Google-auth'd.
      if (kDebugMode) debugPrint('[AuthService] google signOut ignored: $e');
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Generates a random 32-byte alphanumeric string for Apple nonce.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA-256 hash the raw nonce — Apple requires the hashed nonce in the
  /// ID token request.
  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
