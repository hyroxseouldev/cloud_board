// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BillingModel _$BillingModelFromJson(Map<String, dynamic> json) => BillingModel(
  appAccountToken: json['appAccountToken'] as String? ?? '',
  purchasesEnabled: json['purchasesEnabled'] as bool? ?? false,
  productIds:
      (json['productIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  plan: json['plan'] as String? ?? 'free',
  status: json['status'] as String? ?? 'expired',
  validUntilMs: (json['validUntilMs'] as num?)?.toInt() ?? 0,
  grantSource: json['grantSource'] as String?,
  paid: json['paid'] as Map<String, dynamic>?,
);
