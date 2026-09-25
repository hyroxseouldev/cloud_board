import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/usecases/onboarding_actions.dart';
part 'onboarding_controller.g.dart';

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  Future<CenterOnboarding> build() async {
    final uid = ref.watch(authStateProvider.select((value) => value.value?.id));
    if (uid == null) return const CenterOnboarding();
    return ref.watch(onboardingActionsProvider).load();
  }

  void replace(CenterOnboarding value) => state = AsyncData(value);
}

@riverpod
class OnboardingAction extends _$OnboardingAction {
  @override
  AsyncValue<void> build() {
    ref.watch(authStateProvider.select((value) => value.value?.id));
    return const AsyncData(null);
  }

  Future<bool> run(Future<CenterOnboarding?> Function() operation) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(() async {
      final value = await operation();
      if (ref.mounted && value != null) {
        ref.read(onboardingControllerProvider.notifier).replace(value);
      }
    });
    if (!ref.mounted) return false;
    state = result;
    return !state.hasError;
  }

  Future<bool> sendCode(String phone) => run(() async {
    await ref.read(onboardingActionsProvider).sendCode(phone);
    return null;
  });
  Future<bool> verifyCode(String code) =>
      run(() => ref.read(onboardingActionsProvider).verifyCode(code));
  Future<bool> save(
    CenterProfile profile,
    int step, {
    String action = 'save',
  }) => run(
    () => ref
        .read(onboardingActionsProvider)
        .save(
          ref.read(onboardingControllerProvider).requireValue,
          profile,
          step,
          action,
        ),
  );
  Future<bool> reload() =>
      run(() => ref.read(onboardingActionsProvider).load());
  Future<bool> startTrial() =>
      run(() => ref.read(onboardingActionsProvider).startTrial());
}

@riverpod
Future<bool> onboardingRequired(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user?.needsOnboarding != true) return false;
  final progress = await ref.watch(onboardingControllerProvider.future);
  return !progress.completed && !progress.deferred;
}
