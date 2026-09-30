import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/domain/repositories/auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';

part 'auth_use_cases.g.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<void> call() async {
    await _repository.signInWithGoogle();
  }
}

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

@riverpod
SignInWithGoogle signInWithGoogle(Ref ref) =>
    SignInWithGoogle(ref.watch(authRepositoryProvider));

@riverpod
SignOut signOut(Ref ref) => SignOut(ref.watch(authRepositoryProvider));

class SignInWithApple {
  const SignInWithApple(this._repository);
  final AuthRepository _repository;
  Future<void> call() async => _repository.signInWithApple();
}

@riverpod
SignInWithApple signInWithApple(Ref ref) =>
    SignInWithApple(ref.watch(authRepositoryProvider));

class EmailAuthActions {
  const EmailAuthActions(this._repository);
  final AuthRepository _repository;

  Future<void> signIn(String email, String password) async =>
      _repository.signInWithEmail(email.trim(), password);

  Future<void> createAccount(String email, String password) async =>
      _repository.createEmailAccount(email.trim(), password);

  Future<void> resetPassword(String email) =>
      _repository.sendPasswordReset(email.trim());
}

@riverpod
EmailAuthActions emailAuthActions(Ref ref) =>
    EmailAuthActions(ref.watch(authRepositoryProvider));
