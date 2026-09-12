import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthDataSource {
  FirebaseAuthDataSource(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void>? _googleInitialization;

  Future<void> _ensureGoogleInitialized() =>
      _googleInitialization ??= _initializeGoogle();

  Future<void> _initializeGoogle() async {
    try {
      await _googleSignIn.initialize();
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
  }

  Stream<User?> authStateChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> updateProfile({
    required String displayName,
    required String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    await user.updateDisplayName(displayName);
    await user.updatePhotoURL(photoUrl);
    await user.reload();
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }

    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Google 계정 로그인이 필요합니다.');
    }
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
    } else {
      await _ensureGoogleInitialized();
      final googleUser = await _googleSignIn.authenticate();
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          idToken: googleUser.authentication.idToken,
        ),
      );
    }
    await user.getIdToken(true);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    }
  }
}
