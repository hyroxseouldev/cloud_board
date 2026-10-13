import 'package:freezed_annotation/freezed_annotation.dart';
part 'store_entitlement.freezed.dart';

@freezed
abstract class StoreEntitlement with _$StoreEntitlement {
  const StoreEntitlement._();
  const factory StoreEntitlement({
    required String ownerId,
    @Default('awaiting_web') String status,
    @Default(0) int validUntilMs,
    @Default(0) int revision,
    @Default(false) bool serverConfirmed,
    @Default(false) bool canPairDisplay,
    @Default(false) bool canStartClass,
    @Default('') String policyVersion,
    @Default('') String plan,
    int? maxWorkouts,
    @Default(false) bool workoutsUnlimited,
    int? maxSavedSlides,
    @Default(false) bool savedSlidesUnlimited,
    @Default('unknown') String idleScreenCustomization,
    @Default(false) bool canHideCloudBoardLogo,
    @Default(false) bool canUseCenterLogo,
    int? aiSlidesMonthlyLimit,
    int? aiTimerMonthlyLimit,
  }) = _StoreEntitlement;

  /// A missing value is not the unlimited marker. Cached policy may be used
  /// for display; mutations still require the server's final decision.
  bool get policyKnown =>
      policyVersion == 'plan-entitlements-v2' &&
      const {
        'active',
        'trialing',
        'grace_period',
        'canceling',
        'past_due',
      }.contains(status) &&
      const {'free', 'plus', 'premium'}.contains(plan) &&
      (workoutsUnlimited ? maxWorkouts == null : (maxWorkouts ?? -1) >= 0) &&
      (savedSlidesUnlimited
          ? maxSavedSlides == null
          : (maxSavedSlides ?? -1) >= 0) &&
      const {'basic', 'custom'}.contains(idleScreenCustomization) &&
      (aiSlidesMonthlyLimit ?? -1) >= 0 &&
      (aiTimerMonthlyLimit ?? -1) >= 0;
  bool allowsNewClass(String? uid, int serverNowMs) =>
      ownerId == uid &&
      serverConfirmed &&
      canStartClass &&
      validUntilMs > serverNowMs;
}
