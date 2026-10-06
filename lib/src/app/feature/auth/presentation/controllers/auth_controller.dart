import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';

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
      try {
        await ref.read(signInWithGoogleProvider).call();
        return '로그인되었습니다.';
      } catch (error, stack) {
        ref
            .read(errorReporterProvider)
            .capture(error, stack, action: 'auth.signInWithGoogle');
        rethrow;
      }
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
        ref
            .read(errorReporterProvider)
            .capture(error, stack, action: 'auth.signInWithApple');
        state = AsyncError(error, stack);
      }
    } catch (error, stack) {
      ref
          .read(errorReporterProvider)
          .capture(error, stack, action: 'auth.signInWithApple');
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
