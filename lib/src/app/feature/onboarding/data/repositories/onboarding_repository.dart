import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/onboarding/data/datasources/onboarding_data_source.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/models/center_onboarding_model.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/onboarding_repository.dart';
part 'onboarding_repository.g.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this.source);
  final OnboardingDataSource source;
  Future<CenterOnboarding> _call(Map<String, dynamic> input) async =>
      CenterOnboardingModel.fromJson(await source.call(input)).toEntity();
  @override
  Future<CenterOnboarding> load() => _call({'action': 'load'});
  @override
  Future<void> sendCode(String phone) async {
    await source.call({'action': 'sendCode', 'phone': phone});
  }

  @override
  Future<CenterOnboarding> verifyCode(String code) =>
      _call({'action': 'verifyCode', 'code': code});
  @override
  Future<CenterOnboarding> save(
    CenterOnboarding current,
    CenterProfile profile,
    int step,
    String action,
  ) => _call({
    'action': action,
    'profile': CenterOnboardingModel.profileJson(profile),
    'revision': current.revision,
    'step': step,
  });
  @override
  Future<CenterOnboarding> startTrial() => _call({'action': 'startTrial'});
}

@riverpod
OnboardingRepository onboardingRepository(Ref ref) =>
    OnboardingRepositoryImpl(OnboardingDataSource());
