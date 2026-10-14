// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_entitlement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoreEntitlementModel _$StoreEntitlementModelFromJson(
  Map<String, dynamic> json,
) => StoreEntitlementModel(
  status: json['status'] as String? ?? 'awaiting_web',
  validUntilMs: (json['validUntilMs'] as num?)?.toInt() ?? 0,
  revision: (json['revision'] as num?)?.toInt() ?? 0,
  canPairDisplay: json['canPairDisplay'] as bool? ?? false,
  canStartClass: json['canStartClass'] as bool? ?? false,
  policyVersion: json['policyVersion'] as String? ?? '',
  plan: json['plan'] as String? ?? '',
  maxWorkouts: (json['maxWorkouts'] as num?)?.toInt(),
  workoutsUnlimited: json['workoutsUnlimited'] as bool? ?? false,
  maxSavedSlides: (json['maxSavedSlides'] as num?)?.toInt(),
  savedSlidesUnlimited: json['savedSlidesUnlimited'] as bool? ?? false,
  idleScreenCustomization:
      json['idleScreenCustomization'] as String? ?? 'unknown',
  canHideCloudBoardLogo: json['canHideCloudBoardLogo'] as bool? ?? false,
  canUseCenterLogo: json['canUseCenterLogo'] as bool? ?? false,
  aiSlidesMonthlyLimit: (json['aiSlidesMonthlyLimit'] as num?)?.toInt(),
  aiTimerMonthlyLimit: (json['aiTimerMonthlyLimit'] as num?)?.toInt(),
);

Map<String, dynamic> _$StoreEntitlementModelToJson(
  StoreEntitlementModel instance,
) => <String, dynamic>{
  'status': instance.status,
  'validUntilMs': instance.validUntilMs,
  'revision': instance.revision,
  'canPairDisplay': instance.canPairDisplay,
  'canStartClass': instance.canStartClass,
  'policyVersion': instance.policyVersion,
  'plan': instance.plan,
  'maxWorkouts': instance.maxWorkouts,
  'workoutsUnlimited': instance.workoutsUnlimited,
  'maxSavedSlides': instance.maxSavedSlides,
  'savedSlidesUnlimited': instance.savedSlidesUnlimited,
  'idleScreenCustomization': instance.idleScreenCustomization,
  'canHideCloudBoardLogo': instance.canHideCloudBoardLogo,
  'canUseCenterLogo': instance.canUseCenterLogo,
  'aiSlidesMonthlyLimit': instance.aiSlidesMonthlyLimit,
  'aiTimerMonthlyLimit': instance.aiTimerMonthlyLimit,
};
