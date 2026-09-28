import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
part 'billing_model.g.dart';

@JsonSerializable(createToJson: false)
class BillingModel {
  const BillingModel({
    this.appAccountToken = '',
    this.purchasesEnabled = false,
    this.productIds = const [],
    this.plan = 'free',
    this.status = 'expired',
    this.validUntilMs = 0,
    this.grantSource,
    this.paid,
  });
  final String appAccountToken, plan, status;
  final bool purchasesEnabled;
  final List<String> productIds;
  final int validUntilMs;
  final String? grantSource;
  final Map<String, dynamic>? paid;
  factory BillingModel.fromJson(Map<String, dynamic> json) =>
      _$BillingModelFromJson(json);
  BillingStatus toEntity() => BillingStatus(
    appAccountToken: appAccountToken,
    purchasesEnabled: purchasesEnabled,
    productIds: productIds,
    plan: plan,
    status: status,
    validUntilMs: validUntilMs,
    grantSource: grantSource,
    paidStatus: paid?['status'] as String?,
    paidPlan: paid?['plan'] as String?,
    nextProductId: paid?['nextProductId'] as String?,
    autoRenew: paid?['autoRenew'] == true,
    paidExpiresAtMs: (paid?['expiresAtMs'] as num?)?.toInt() ?? 0,
  );
}
