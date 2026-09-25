import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';

abstract interface class OnboardingRepository {
  Future<CenterOnboarding> load();
  Future<void> sendCode(String phone);
  Future<CenterOnboarding> verifyCode(String code);
  Future<CenterOnboarding> save(
    CenterOnboarding current,
    CenterProfile profile,
    int step,
    String action,
  );
  Future<CenterOnboarding> startTrial();
}
