import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

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
