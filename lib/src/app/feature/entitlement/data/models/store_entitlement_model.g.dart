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
);

Map<String, dynamic> _$StoreEntitlementModelToJson(
  StoreEntitlementModel instance,
) => <String, dynamic>{
  'status': instance.status,
  'validUntilMs': instance.validUntilMs,
  'revision': instance.revision,
  'canPairDisplay': instance.canPairDisplay,
  'canStartClass': instance.canStartClass,
};
