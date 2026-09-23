import 'package:cloud_board/src/app/feature/entitlement/domain/profile_entitlements.dart';
import 'package:cloud_board/src/app/feature/profile/data/models/user_profile_model.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = {
    'uid': 'u',
    'email': 'test@example.com',
    'displayName': 'Test',
    'photoUrl': null,
  };
  const base = {
    'managed': true,
    'validUntilMs': 2000,
    'status': 'active',
    'displayLimit': 3,
  };
  test(
    'profile shows explicit Premium unlimited and Plus simultaneous limit',
    () {
      final premium = UserProfileModel.fromJson(
        profileEntitlements(original, {
          ...base,
          'plan': 'premium',
          'displaysUnlimited': true,
        }, 1000),
      ).toEntity();
      expect(premium.planLabel, 'CloudBoard 프리미엄');
      expect(premium.displayLimitLabel, '디스플레이 무제한');
      final plus = UserProfileModel.fromJson(
        profileEntitlements(original, {
          ...base,
          'plan': 'plus',
          'maxActiveDisplays': 1,
          'displaysUnlimited': false,
        }, 1000),
      ).toEntity();
      expect(plus.planLabel, 'CloudBoard 플러스');
      expect(plus.displayLimitLabel, '디스플레이 동시 1대');
    },
  );
  test(
    'missing marker never grants unlimited; legacy profile and expiry survive',
    () {
      final legacy = profileEntitlements(original, base, 1000);
      expect(legacy['subscriptionPlan'], 'cloudboard_pro');
      expect(legacy['displayLimit'], 3);
      expect(
        profileEntitlements(original, {
          ...base,
          'plan': 'premium',
        }, 1000)['displayLimit'],
        3,
      );
      expect(
        profileEntitlements(original, null, 1000)['subscriptionPlan'],
        'free',
      );
      expect(
        profileEntitlements(original, base, 3000)['subscriptionPlan'],
        'free',
      );
      expect(
        DateTime.parse(legacy['pilotEndsAt'] as String).millisecondsSinceEpoch,
        2000,
      );
    },
  );
}
