import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';

part 'user_profile_model.g.dart';

@JsonSerializable()
class UserProfileModel {
  const UserProfileModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.partnerTier,
    required this.subscriptionPlan,
    required this.subscriptionStatus,
    required this.pilotEndsAt,
    required this.displayLimit,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  @JsonKey(defaultValue: 'pilot')
  final String partnerTier;
  @JsonKey(defaultValue: 'cloudboard_pro')
  final String subscriptionPlan;
  @JsonKey(defaultValue: 'free')
  final String subscriptionStatus;
  final String? pilotEndsAt;
  @JsonKey(defaultValue: 3)
  final int displayLimit;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileModelToJson(this);

  UserProfile toEntity() => UserProfile(
    id: uid,
    email: email,
    displayName: displayName,
    photoUrl: photoUrl,
    partnerTier: PartnerTier.values.firstWhere(
      (value) => value.name == partnerTier,
      orElse: () => PartnerTier.pilot,
    ),
    subscriptionPlan: subscriptionPlan,
    subscriptionStatus: SubscriptionStatus.values.firstWhere(
      (value) => value.name == subscriptionStatus,
      orElse: () => SubscriptionStatus.free,
    ),
    pilotEndsAt: pilotEndsAt == null ? null : DateTime.tryParse(pilotEndsAt!),
    displayLimit: displayLimit,
  );
}
