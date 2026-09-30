import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/domain/usecases/auth_use_cases.dart';

part 'email_auth_controller.g.dart';

/// Only a safe description is exposed to UI/diagnostics, never credentials or
/// the provider exception payload.
class EmailAuthFailure implements Exception {
  const EmailAuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String emailAuthErrorMessage(Object error) {
  final code = error is FirebaseAuthException ? error.code : null;
  return switch (code) {
    'invalid-email' => '이메일 주소를 확인해 주세요.',
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => '이메일 또는 비밀번호를 확인해 주세요.',
    'email-already-in-use' || 'account-exists-with-different-credential' =>
      '이미 사용 중인 이메일입니다. 기존 로그인 방법을 선택하거나 비밀번호를 재설정해 주세요.',
    'weak-password' || 'password-does-not-meet-requirements' =>
      '더 안전한 비밀번호를 입력해 주세요. 8자 이상을 권장합니다.',
    'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
    'network-request-failed' => '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
    'user-disabled' => '사용이 중지된 계정입니다. 계정 안내에서 문의해 주세요.',
    'operation-not-allowed' => '이메일 로그인을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
    _ => '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
  };
}

@riverpod
class EmailAuthController extends _$EmailAuthController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  void clear() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? message,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      try {
        await operation();
        return message;
      } catch (error) {
        throw EmailAuthFailure(emailAuthErrorMessage(error));
      }
    });
    if (ref.mounted) state = result;
  }

  Future<void> signIn(String email, String password) =>
      _run(() => ref.read(emailAuthActionsProvider).signIn(email, password));

  Future<void> createAccount(String email, String password) => _run(
    () => ref.read(emailAuthActionsProvider).createAccount(email, password),
  );

  Future<void> resetPassword(String email) => _run(
    () => ref.read(emailAuthActionsProvider).resetPassword(email),
    message: '재설정 가능한 계정이라면 이메일로 링크를 보냈어요. 스팸함도 확인해 주세요.',
  );
}
