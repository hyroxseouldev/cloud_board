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

/// Kept alive only by the current onboarding view, never persisted across launch.
/// A returning account's load does not create a new activation celebration.
@riverpod
class OnboardingCompletion extends _$OnboardingCompletion {
  @override
  bool build() {
    ref.watch(authStateProvider.select((value) => value.value?.id));
    return false;
  }

  void show() => state = true;
}

@riverpod
class OnboardingAction extends _$OnboardingAction {
  int _generation = 0;
  @override
  AsyncValue<void> build() {
    _generation++;
    ref.watch(authStateProvider.select((value) => value.value?.id));
    return const AsyncData(null);
  }

  Future<bool> run(
    Future<CenterOnboarding?> Function() operation, {
    bool showCompletion = false,
  }) async {
    if (state.isLoading) return false;
    final userId = ref.read(authStateProvider).value?.id;
    final generation = _generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(() async {
      final value = await operation();
      if (ref.mounted &&
          generation == _generation &&
          ref.read(authStateProvider).value?.id == userId &&
          value != null) {
        if (showCompletion && value.serviceReady) {
          ref.read(onboardingCompletionProvider.notifier).show();
        }
        ref.read(onboardingControllerProvider.notifier).replace(value);
      }
    });
    if (!ref.mounted ||
        generation != _generation ||
        ref.read(authStateProvider).value?.id != userId) {
      return false;
    }
    state = result;
    return !state.hasError;
  }

  Future<bool> sendCode(String phone) => run(() async {
    await ref.read(onboardingActionsProvider).sendCode(phone);
    return null;
  });
  Future<bool> verifyCode(String code) => run(
    () => ref.read(onboardingActionsProvider).verifyCode(code),
    showCompletion: true,
  );
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
  Future<bool> reload() => run(
    () => ref.read(onboardingActionsProvider).load(),
    showCompletion:
        ref.read(onboardingControllerProvider).value?.serviceReady != true,
  );
}

@riverpod
Future<bool> onboardingRequired(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user?.needsOnboarding != true) return false;
  final progress = await ref.watch(onboardingControllerProvider.future);
  return !progress.serviceReady;
}
