import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/domain/usecases/auth_use_cases.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<void> signInWithGoogle() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(signInWithGoogleProvider).call();
      return '로그인되었습니다.';
    });
  }

  Future<void> signInWithApple() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(signInWithAppleProvider).call();
      state = const AsyncData('로그인되었습니다.');
    } on FirebaseAuthException catch (error, stack) {
      if (const {
        'canceled',
        'cancelled',
        'web-context-canceled',
        'popup-closed-by-user',
        'user-cancelled',
      }.contains(error.code)) {
        state = const AsyncData(null);
      } else {
        final message =
            const {
              'account-exists-with-different-credential',
              'credential-already-in-use',
              'email-already-in-use',
            }.contains(error.code)
            ? '이미 가입한 로그인 방식으로 로그인해 주세요. 기존 계정을 자동으로 합치지 않습니다.'
            : error.code == 'operation-not-allowed'
            ? 'Apple 로그인을 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.'
            : 'Apple 로그인에 실패했습니다. 다시 시도해 주세요.';
        state = AsyncError(StateError(message), stack);
      }
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(signOutProvider).call();
      return '로그아웃되었습니다.';
    });
  }
}
