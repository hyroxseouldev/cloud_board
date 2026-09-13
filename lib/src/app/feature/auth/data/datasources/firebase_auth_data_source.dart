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

  Future<UserCredential> signInWithApple() =>
      _auth.signInWithProvider(AppleAuthProvider());

  /// Apple authorization codes stay in memory and are never persisted or logged.
  Future<void> prepareAccountDeletion() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('계정 로그인이 필요합니다.');
    }
    final providers = user.providerData.map((item) => item.providerId).toSet();
    if (providers.contains('apple.com')) {
      final result = await user.reauthenticateWithProvider(AppleAuthProvider());
      final code = result.additionalUserInfo?.authorizationCode;
      if (code == null || code.isEmpty) {
        throw StateError(
          'Apple 본인 확인 정보를 받지 못했습니다. iPhone 또는 iPad에서 다시 시도해 주세요.',
        );
      }
      // Revoke before destructive cleanup; failure must not report deletion.
      await _auth.revokeTokenWithAuthorizationCode(code);
      await user.getIdToken(true);
    } else if (providers.contains('google.com')) {
      await reauthenticateWithGoogle();
    } else {
      throw StateError('지원하지 않는 로그인 방식입니다. 계정 삭제 안내에서 문의해 주세요.');
    }
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
    final usedGoogle = _googleInitialization != null;
    await _auth.signOut();
    if (!kIsWeb && usedGoogle) {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    }
  }
}
