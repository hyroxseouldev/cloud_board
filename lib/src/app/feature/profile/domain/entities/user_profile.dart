import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

enum PartnerTier { trial, pilot, earlyPartner, pro, enterprise }

enum SubscriptionStatus { free, trialing, active, pastDue, canceled }

extension PartnerTierLabel on PartnerTier {
  String get label => switch (this) {
    PartnerTier.trial => '체험 중',
    PartnerTier.pilot => '파일럿 파트너',
    PartnerTier.earlyPartner => '얼리 파트너',
    PartnerTier.pro => 'CloudBoard Pro',
    PartnerTier.enterprise => 'Enterprise',
  };
}

extension SubscriptionStatusLabel on SubscriptionStatus {
  String get label => switch (this) {
    SubscriptionStatus.free => '파일럿 무료 이용',
    SubscriptionStatus.trialing => '무료 체험 중',
    SubscriptionStatus.active => '정상 이용 중',
    SubscriptionStatus.pastDue => '결제 확인 필요',
    SubscriptionStatus.canceled => '이용 종료',
  };
}

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String email,
    required String displayName,
    required String? photoUrl,
    @Default(PartnerTier.pilot) PartnerTier partnerTier,
    @Default('cloudboard_pro') String subscriptionPlan,
    @Default(SubscriptionStatus.free) SubscriptionStatus subscriptionStatus,
    DateTime? pilotEndsAt,
    @Default(3) int displayLimit,
  }) = _UserProfile;
}
