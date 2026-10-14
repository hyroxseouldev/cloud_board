// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audience_branding_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudienceBrandingModel _$AudienceBrandingModelFromJson(
  Map<String, dynamic> json,
) => AudienceBrandingModel(
  ownerId: json['ownerId'] as String,
  policyVersion: json['policyVersion'] as String,
  audienceLogoVersion: json['audienceLogoVersion'] as String,
  audienceLogoScope: json['audienceLogoScope'] as String,
  showCloudBoardLogo: json['showCloudBoardLogo'] as bool,
  revision: (json['revision'] as num).toInt(),
  projectionRevision: (json['projectionRevision'] as num).toInt(),
  appliedAtMs: (json['appliedAtMs'] as num).toInt(),
  validUntilMs: (json['validUntilMs'] as num).toInt(),
);

Map<String, dynamic> _$AudienceBrandingModelToJson(
  AudienceBrandingModel instance,
) => <String, dynamic>{
  'ownerId': instance.ownerId,
  'policyVersion': instance.policyVersion,
  'audienceLogoVersion': instance.audienceLogoVersion,
  'audienceLogoScope': instance.audienceLogoScope,
  'showCloudBoardLogo': instance.showCloudBoardLogo,
  'revision': instance.revision,
  'projectionRevision': instance.projectionRevision,
  'appliedAtMs': instance.appliedAtMs,
  'validUntilMs': instance.validUntilMs,
};
