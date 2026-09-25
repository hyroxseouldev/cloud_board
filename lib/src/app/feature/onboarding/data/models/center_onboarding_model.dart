import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
part 'center_onboarding_model.g.dart';

@JsonSerializable()
class CenterOnboardingModel {
  const CenterOnboardingModel({
    this.phoneRequired = true,
    this.storeId = '',
    this.profile = const {},
    this.step = 0,
    this.revision = 0,
    this.completed = false,
    this.deferred = false,
    this.status = 'pending_connection',
    this.hasAccess = false,
    this.trialEligible = true,
    this.trialStartedAtMs = 0,
    this.trialEndsAtMs = 0,
    this.serverNowMs = 0,
    this.suggestedTrialEndsAtMs = 0,
  });
  final bool phoneRequired, completed, deferred, hasAccess, trialEligible;
  final String storeId, status;
  final Map<String, dynamic> profile;
  final int step,
      revision,
      trialStartedAtMs,
      trialEndsAtMs,
      serverNowMs,
      suggestedTrialEndsAtMs;
  factory CenterOnboardingModel.fromJson(Map<String, dynamic> json) =>
      _$CenterOnboardingModelFromJson(json);
  Map<String, dynamic> toJson() => _$CenterOnboardingModelToJson(this);
  CenterOnboarding toEntity() => CenterOnboarding(
    phoneRequired: phoneRequired,
    storeId: storeId,
    step: step,
    revision: revision,
    completed: completed,
    deferred: deferred,
    status: status,
    hasAccess: hasAccess,
    trialEligible: trialEligible,
    trialStartedAtMs: trialStartedAtMs,
    trialEndsAtMs: trialEndsAtMs,
    serverNowMs: serverNowMs,
    suggestedTrialEndsAtMs: suggestedTrialEndsAtMs,
    profile: CenterProfile(
      purpose: profile['purpose'] as String?,
      role: profile['role'] as String?,
      centerName: profile['centerName'] as String? ?? '',
      centerTypes: List<String>.from(profile['centerTypes'] as List? ?? []),
      province: profile['province'] as String? ?? '',
      district: profile['district'] as String? ?? '',
      undecidedName: profile['undecidedName'] == true,
      undecidedRegion: profile['undecidedRegion'] == true,
      environment: Map<String, String>.from(
        profile['environment'] as Map? ?? {},
      ),
      environmentSkipped: profile['environmentSkipped'] == true,
      classTypes: List<String>.from(profile['classTypes'] as List? ?? []),
      guidance: List<String>.from(profile['guidance'] as List? ?? []),
      priorities: List<String>.from(profile['priorities'] as List? ?? []),
      controllers: List<String>.from(profile['controllers'] as List? ?? []),
      floorArea: profile['floorArea'] as String? ?? '',
    ),
  );
  static Map<String, dynamic> profileJson(CenterProfile p) => {
    if (p.purpose != null) 'purpose': p.purpose,
    if (p.role != null) 'role': p.role,
    'centerName': p.centerName.trim(),
    'centerTypes': p.centerTypes,
    'province': p.province.trim(),
    'district': p.district.trim(),
    'undecidedName': p.undecidedName,
    'undecidedRegion': p.undecidedRegion,
    'environment': p.environment,
    'environmentSkipped': p.environmentSkipped,
    'classTypes': p.classTypes,
    'guidance': p.guidance,
    'priorities': p.priorities,
    'controllers': p.controllers,
    'floorArea': p.floorArea,
  };
}
