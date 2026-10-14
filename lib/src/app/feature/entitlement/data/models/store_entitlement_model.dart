import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
part 'store_entitlement_model.g.dart';

@JsonSerializable()
class StoreEntitlementModel {
  const StoreEntitlementModel({
    this.status = 'awaiting_web',
    this.validUntilMs = 0,
    this.revision = 0,
    this.canPairDisplay = false,
    this.canStartClass = false,
    this.policyVersion = '',
    this.plan = '',
    this.maxWorkouts,
    this.workoutsUnlimited = false,
    this.maxSavedSlides,
    this.savedSlidesUnlimited = false,
    this.idleScreenCustomization = 'unknown',
    this.canHideCloudBoardLogo = false,
    this.canUseCenterLogo = false,
    this.aiSlidesMonthlyLimit,
    this.aiTimerMonthlyLimit,
  });
  @JsonKey(defaultValue: 'awaiting_web')
  final String status;
  @JsonKey(defaultValue: 0)
  final int validUntilMs;
  @JsonKey(defaultValue: 0)
  final int revision;
  @JsonKey(defaultValue: false)
  final bool canPairDisplay;
  @JsonKey(defaultValue: false)
  final bool canStartClass;
  @JsonKey(defaultValue: '')
  final String policyVersion;
  @JsonKey(defaultValue: '')
  final String plan;
  final int? maxWorkouts;
  @JsonKey(defaultValue: false)
  final bool workoutsUnlimited;
  final int? maxSavedSlides;
  @JsonKey(defaultValue: false)
  final bool savedSlidesUnlimited;
  @JsonKey(defaultValue: 'unknown')
  final String idleScreenCustomization;
  @JsonKey(defaultValue: false)
  final bool canHideCloudBoardLogo;
  @JsonKey(defaultValue: false)
  final bool canUseCenterLogo;
  final int? aiSlidesMonthlyLimit;
  final int? aiTimerMonthlyLimit;
  factory StoreEntitlementModel.fromJson(Map<String, dynamic> json) =>
      _$StoreEntitlementModelFromJson(_storageFields(json));
  Map<String, dynamic> toJson() => _$StoreEntitlementModelToJson(this);
  StoreEntitlement toEntity(String uid, bool confirmed, int now) =>
      StoreEntitlement(
        ownerId: uid,
        status: status,
        validUntilMs: validUntilMs,
        revision: revision,
        serverConfirmed: confirmed,
        canPairDisplay:
            canPairDisplay &&
            (status == 'pending_connection' || validUntilMs > now),
        canStartClass: canStartClass && validUntilMs > now,
        policyVersion: validUntilMs > now ? policyVersion : '',
        plan: plan,
        maxWorkouts: maxWorkouts,
        workoutsUnlimited: workoutsUnlimited,
        maxSavedSlides: maxSavedSlides,
        savedSlidesUnlimited: savedSlidesUnlimited,
        idleScreenCustomization: idleScreenCustomization,
        canHideCloudBoardLogo: canHideCloudBoardLogo && validUntilMs > now,
        canUseCenterLogo: canUseCenterLogo && validUntilMs > now,
        aiSlidesMonthlyLimit: aiSlidesMonthlyLimit,
        aiTimerMonthlyLimit: aiTimerMonthlyLimit,
      );
}

Map<String, dynamic> _storageFields(Map<String, dynamic> json) {
  final result = Map<String, dynamic>.of(json);
  // Server-owned legacy aliases describe the same saved-slide resource. Never
  // combine contradictory primary/alias values into an unlimited permission.
  var conflictingSlides = false;
  for (final (primary, alias) in const [
    ('maxSavedSlides', 'maxFavorites'),
    ('savedSlidesUnlimited', 'favoritesUnlimited'),
  ]) {
    if (!json.containsKey(primary)) {
      if (json.containsKey(alias)) result[primary] = json[alias];
    } else if (json.containsKey(alias) && json[primary] != json[alias]) {
      conflictingSlides = true;
    }
  }
  if (conflictingSlides) {
    result['maxSavedSlides'] = -1;
    result['savedSlidesUnlimited'] = false;
  }
  // json_serializable otherwise truncates fractions with num.toInt(). Invalid
  // quota values must remain unknown, including true + a malformed finite cap.
  for (final key in ['maxWorkouts', 'maxSavedSlides']) {
    final value = result[key];
    if (value != null &&
        (value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > 9007199254740991 ||
            value != value.truncateToDouble())) {
      result[key] = -1;
    }
  }
  return result;
}
