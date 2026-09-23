import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

enum PartnerTier { free, trial, pilot, earlyPartner, pro, enterprise }

enum SubscriptionStatus { free, trialing, active, pastDue, canceled }

extension PartnerTierLabel on PartnerTier {
  String get label => switch (this) {
    PartnerTier.free => '무료 준비',
    PartnerTier.trial => '체험 중',
    PartnerTier.pilot => '파일럿 파트너',
    PartnerTier.earlyPartner => '얼리 파트너',
    PartnerTier.pro => 'CloudBoard Pro',
    PartnerTier.enterprise => 'Enterprise',
  };
}

extension SubscriptionStatusLabel on SubscriptionStatus {
  String get label => switch (this) {
    SubscriptionStatus.free => '수업 준비 가능',
    SubscriptionStatus.trialing => '무료 체험 중',
    SubscriptionStatus.active => '정상 이용 중',
    SubscriptionStatus.pastDue => '결제 확인 필요',
    SubscriptionStatus.canceled => '이용 종료',
  };
}

extension UserProfilePlan on UserProfile {
  bool get hasPlanDisplayPolicy =>
      subscriptionPlan == 'plus' || subscriptionPlan == 'premium';
  bool get unlimitedDisplays =>
      subscriptionPlan == 'premium' && displayLimit == -1;
  String get planLabel => switch (subscriptionPlan) {
    'plus' => 'CloudBoard 플러스',
    'premium' => 'CloudBoard 프리미엄',
    _ => partnerTier.label,
  };
  String get displayLimitLabel => unlimitedDisplays
      ? '디스플레이 무제한'
      : '디스플레이 ${hasPlanDisplayPolicy ? "동시 " : ""}$displayLimit대';
}

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    required String displayName,
    required String? photoUrl,
    @Default(PartnerTier.free) PartnerTier partnerTier,
    @Default('free') String subscriptionPlan,
    @Default(SubscriptionStatus.free) SubscriptionStatus subscriptionStatus,
    DateTime? pilotEndsAt,
    @Default(3) int displayLimit,
  }) = _UserProfile;
}
