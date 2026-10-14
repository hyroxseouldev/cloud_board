import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_resource_limit.dart';
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

  /// Storage display/advisory checks require only this resource's contract.
  /// The data mapper clears policyVersion at the server-clock expiry boundary;
  /// unrelated AI/branding fields still retain the stricter policyKnown gate.
  PlanResourceLimit limitFor(String resource) {
    if (validUntilMs <= 0 ||
        !const {
          'plan-entitlements-v1',
          'plan-entitlements-v2',
        }.contains(policyVersion) ||
        !const {
          'active',
          'trialing',
          'grace_period',
          'canceling',
          'past_due',
        }.contains(status) ||
        !const {
          'free',
          'plus',
          'premium',
          'legacy',
          'cloudboard_pro',
        }.contains(plan)) {
      return const PlanResourceLimit.unknown();
    }
    final (limit, unlimited) = switch (resource) {
      'workouts' => (maxWorkouts, workoutsUnlimited),
      'savedSlides' => (maxSavedSlides, savedSlidesUnlimited),
      _ => (null, false),
    };
    if (resource != 'workouts' && resource != 'savedSlides') {
      return const PlanResourceLimit.unknown();
    }
    if (const {'free', 'plus', 'premium'}.contains(plan)) {
      // Named plans are normalized by the server to this versioned contract.
      // A Free v2 grant claiming unlimited storage is contradictory. We still
      // require the explicit fields below; never fill missing values from plan.
      final v1 = policyVersion == 'plan-entitlements-v1';
      final int? expected = resource == 'workouts'
          ? !v1 && plan == 'free'
                ? 7
                : null
          : plan == 'premium'
          ? null
          : v1 || plan == 'free'
          ? 3
          : 30;
      if (limit != expected || unlimited != (expected == null)) {
        return const PlanResourceLimit.unknown();
      }
    }
    if (unlimited) {
      return limit == null
          ? const PlanResourceLimit.unlimited()
          : const PlanResourceLimit.unknown();
    }
    return limit != null && limit >= 0
        ? PlanResourceLimit.finite(limit)
        : const PlanResourceLimit.unknown();
  }

  bool allowsNewClass(String? uid, int serverNowMs) =>
      ownerId == uid &&
      serverConfirmed &&
      canStartClass &&
      validUntilMs > serverNowMs;
}
