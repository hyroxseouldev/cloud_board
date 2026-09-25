import 'package:freezed_annotation/freezed_annotation.dart';
part 'center_onboarding.freezed.dart';

@freezed
abstract class CenterProfile with _$CenterProfile {
  const CenterProfile._();
  const factory CenterProfile({
    String? purpose,
    String? role,
    @Default('') String centerName,
    @Default([]) List<String> centerTypes,
    @Default('') String province,
    @Default('') String district,
    @Default(false) bool undecidedName,
    @Default(false) bool undecidedRegion,
    @Default({}) Map<String, String> environment,
    @Default(false) bool environmentSkipped,
    @Default([]) List<String> classTypes,
    @Default([]) List<String> guidance,
    @Default([]) List<String> priorities,
    @Default([]) List<String> controllers,
    @Default('') String floorArea,
  }) = _CenterProfile;
  bool get isComplete =>
      purpose != null &&
      role != null &&
      centerTypes.isNotEmpty &&
      (centerName.trim().isNotEmpty ||
          (purpose != 'operating' && undecidedName)) &&
      ((province.trim().isNotEmpty && district.trim().isNotEmpty) ||
          (purpose != 'operating' && undecidedRegion));
}

@freezed
abstract class CenterOnboarding with _$CenterOnboarding {
  const factory CenterOnboarding({
    @Default(true) bool phoneRequired,
    @Default('') String storeId,
    @Default(CenterProfile()) CenterProfile profile,
    @Default(0) int step,
    @Default(0) int revision,
    @Default(false) bool completed,
    @Default(false) bool deferred,
    @Default('pending_connection') String status,
    @Default(false) bool hasAccess,
    @Default(true) bool trialEligible,
    @Default(0) int trialStartedAtMs,
    @Default(0) int trialEndsAtMs,
    @Default(0) int serverNowMs,
    @Default(0) int suggestedTrialEndsAtMs,
  }) = _CenterOnboarding;
}
