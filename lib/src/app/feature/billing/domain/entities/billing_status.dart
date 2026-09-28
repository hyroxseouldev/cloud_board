import 'package:freezed_annotation/freezed_annotation.dart';
part 'billing_status.freezed.dart';

@freezed
abstract class BillingStatus with _$BillingStatus {
  const BillingStatus._();
  const factory BillingStatus({
    @Default('') String appAccountToken,
    @Default(false) bool purchasesEnabled,
    @Default([]) List<String> productIds,
    @Default('free') String plan,
    @Default('expired') String status,
    @Default(0) int validUntilMs,
    String? grantSource,
    String? paidStatus,
    String? paidPlan,
    String? paidSource,
    @Default([]) List<String> paidStores,
    String? nextProductId,
    @Default(false) bool autoRenew,
    @Default(0) int paidExpiresAtMs,
  }) = _BillingStatus;

  String get planLabel => switch (plan) {
    'premium' => '프리미엄',
    'plus' => '플러스',
    'free' => '무료',
    _ => '기존 이용 플랜',
  };
  String get statusLabel => switch (status) {
    'trialing' => '무료 체험 중',
    'active' => '이용 중',
    'grace_period' => '결제 확인 필요 · 유예 기간',
    'billing_retry' => '결제 확인 필요',
    'paused' => '구독 일시중지',
    'pending' => '결제 승인 대기',
    'revoked' => '환불 또는 이용 종료',
    _ => '이용 기간 종료',
  };
}

@freezed
abstract class BillingOffer with _$BillingOffer {
  const factory BillingOffer({required String id, required String price}) =
      _BillingOffer;
}

enum StorePurchasePhase { pending, purchased, restored, canceled, error }

@freezed
abstract class StorePurchase with _$StorePurchase {
  const factory StorePurchase({
    required String key,
    required StorePurchasePhase phase,
    required String signedTransaction,
    @Default('app_store') String store,
    String? error,
  }) = _StorePurchase;
}

@freezed
abstract class BillingActivity with _$BillingActivity {
  const factory BillingActivity({
    @Default(false) bool busy,
    @Default(false) bool needsVerification,
    String? message,
    @Default(false) bool error,
  }) = _BillingActivity;
}
