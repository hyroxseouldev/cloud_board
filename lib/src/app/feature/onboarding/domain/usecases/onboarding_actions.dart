import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/onboarding_repository.dart';
part 'onboarding_actions.g.dart';

class OnboardingActions {
  const OnboardingActions(this.repository);
  final OnboardingRepository repository;
  Future<CenterOnboarding> load() => repository.load();
  Future<void> sendCode(String phone) => repository.sendCode(phone);
  Future<CenterOnboarding> verifyCode(String code) =>
      repository.verifyCode(code);
  Future<CenterOnboarding> save(
    CenterOnboarding current,
    CenterProfile profile,
    int step,
    String action,
  ) {
    if (action == 'complete' && !profile.isComplete) {
      throw StateError('센터 기본 정보를 입력해 주세요.');
    }
    return repository.save(current, profile, step, action);
  }

  Future<CenterOnboarding> startTrial() => repository.startTrial();
}

@riverpod
OnboardingActions onboardingActions(Ref ref) =>
    OnboardingActions(ref.watch(onboardingRepositoryProvider));
