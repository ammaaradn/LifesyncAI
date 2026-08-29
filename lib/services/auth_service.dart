import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

/// Thrown by [AuthService] with a message that's already safe/friendly to
/// show directly in the UI (a SnackBar, a form error, etc).
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Wraps Firebase Authentication + the `users/{uid}` Firestore profile doc.
///
/// This is the single place the rest of the app talks to for signup, login,
/// logout, and the current auth state.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Emits the current user whenever sign-in state changes (including on
  /// app start, once Firebase has restored any existing session).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Creates a Firebase Auth account, sets the display name, and writes a
  /// matching profile document to `users/{uid}` in Firestore.
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(name.trim());

      // Confirms the signer actually owns this email address. Not enforced
      // as a login gate (that would lock people out of a free app over a
      // missed email), but it's what makes `user.emailVerified` meaningful
      // anywhere the UI wants to show it.
      unawaited(credential.user?.sendEmailVerification());

      final profile = UserModel(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );

      try {
        await _firestore
            .collection('users')
            .doc(profile.uid)
            .set(profile.toMap());
      } on FirebaseException catch (e) {
        throw AuthException(
          'Account created, but saving your profile failed (${e.code}). '
          'Please check your Firestore security rules.',
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageForCode(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Re-sends the verification email to the current user, if any and if
  /// they aren't already verified.
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Sends a Firebase password-reset email.
  ///
  /// Deliberately does *not* distinguish "no account with that email" from
  /// "email sent" — surfacing that difference lets an attacker enumerate
  /// which emails have accounts by trying them here one at a time. The UI
  /// should show the same "check your inbox" message regardless of whether
  /// this actually sent anything.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AuthException(_messageForCode(e.code));
    }
  }

  /// Maps Firebase's error codes to short, user-facing messages.
  String _messageForCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'That doesn\'t look like a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      // Deliberately the same message as wrong-password: telling a login
      // attempt "no account with that email" lets an attacker enumerate
      // registered emails by trying them here one at a time.
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
