import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Future<AuthUser> signInWithEmail(String email, String password);

  Future<AuthUser> createEmailAccount(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
