// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'center_onboarding_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CenterOnboardingModel _$CenterOnboardingModelFromJson(
  Map<String, dynamic> json,
) => CenterOnboardingModel(
  phoneRequired: json['phoneRequired'] as bool? ?? true,
  storeId: json['storeId'] as String? ?? '',
  profile: json['profile'] as Map<String, dynamic>? ?? const {},
  step: (json['step'] as num?)?.toInt() ?? 0,
  revision: (json['revision'] as num?)?.toInt() ?? 0,
  completed: json['completed'] as bool? ?? false,
  deferred: json['deferred'] as bool? ?? false,
  status: json['status'] as String? ?? 'pending_connection',
  hasAccess: json['hasAccess'] as bool? ?? false,
  trialEligible: json['trialEligible'] as bool? ?? true,
  trialStartedAtMs: (json['trialStartedAtMs'] as num?)?.toInt() ?? 0,
  trialEndsAtMs: (json['trialEndsAtMs'] as num?)?.toInt() ?? 0,
  serverNowMs: (json['serverNowMs'] as num?)?.toInt() ?? 0,
  suggestedTrialEndsAtMs:
      (json['suggestedTrialEndsAtMs'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CenterOnboardingModelToJson(
  CenterOnboardingModel instance,
) => <String, dynamic>{
  'phoneRequired': instance.phoneRequired,
  'completed': instance.completed,
  'deferred': instance.deferred,
  'hasAccess': instance.hasAccess,
  'trialEligible': instance.trialEligible,
  'storeId': instance.storeId,
  'status': instance.status,
  'profile': instance.profile,
  'step': instance.step,
  'revision': instance.revision,
  'trialStartedAtMs': instance.trialStartedAtMs,
  'trialEndsAtMs': instance.trialEndsAtMs,
  'serverNowMs': instance.serverNowMs,
  'suggestedTrialEndsAtMs': instance.suggestedTrialEndsAtMs,
};
