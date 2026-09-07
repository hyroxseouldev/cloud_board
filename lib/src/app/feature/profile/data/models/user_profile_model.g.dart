// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfileModel _$UserProfileModelFromJson(Map<String, dynamic> json) =>
    UserProfileModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      partnerTier: json['partnerTier'] as String? ?? 'pilot',
      subscriptionPlan: json['subscriptionPlan'] as String? ?? 'cloudboard_pro',
      subscriptionStatus: json['subscriptionStatus'] as String? ?? 'free',
      pilotEndsAt: json['pilotEndsAt'] as String?,
      displayLimit: (json['displayLimit'] as num?)?.toInt() ?? 3,
    );

Map<String, dynamic> _$UserProfileModelToJson(UserProfileModel instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'email': instance.email,
      'displayName': instance.displayName,
      'photoUrl': instance.photoUrl,
      'partnerTier': instance.partnerTier,
      'subscriptionPlan': instance.subscriptionPlan,
      'subscriptionStatus': instance.subscriptionStatus,
      'pilotEndsAt': instance.pilotEndsAt,
      'displayLimit': instance.displayLimit,
    };
