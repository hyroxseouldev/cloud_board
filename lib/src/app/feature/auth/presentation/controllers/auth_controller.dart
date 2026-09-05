import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/auth_use_cases.dart';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(signInWithGoogleProvider).call();
      return '로그인되었습니다.';
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(signOutProvider).call();
      return '로그아웃되었습니다.';
    });
  }
}
