/// A missing unlimited marker must never turn an unknown plan into Premium.
Map<String, dynamic> profileEntitlements(
  Map<String, dynamic>? profile,
  Map<String, dynamic>? access,
  int nowMs,
) {
  if (access == null || access['managed'] != true) {
    return {
      ...?profile,
      'partnerTier': 'free',
      'subscriptionPlan': 'free',
      'subscriptionStatus': 'free',
      'displayLimit': 0,
      'planPolicyKnown': false,
    };
  }
  final until = (access['validUntilMs'] as num?)?.toInt() ?? 0;
  final valid = until > nowMs;
  final premium =
      access['plan'] == 'premium' && access['displaysUnlimited'] == true;
  final plus =
      access['plan'] == 'plus' &&
      (access['maxActiveDisplays'] == 1 || access['maxActiveDisplays'] == 3) &&
      access['displaysUnlimited'] == false;
  final free =
      access['plan'] == 'free' &&
      access['canStartClass'] == true &&
      access['maxActiveDisplays'] == 1 &&
      access['displaysUnlimited'] == false;
  final status = access['status'];
  return {
    ...?profile,
    'planPolicyKnown':
        valid && access['policyVersion'] == 'plan-entitlements-v2',
    'partnerTier': !valid || free
        ? 'free'
        : status == 'trialing'
        ? 'trial'
        : 'pro',
    'subscriptionPlan': !valid || free
        ? 'free'
        : premium
        ? 'premium'
        : plus
        ? 'plus'
        : 'cloudboard_pro',
    'subscriptionStatus': !valid
        ? 'canceled'
        : free
        ? 'free'
        : status == 'trialing'
        ? 'trialing'
        : status == 'past_due'
        ? 'pastDue'
        : 'active',
    'displayLimit': !valid
        ? 0
        : premium
        ? -1
        : free
        ? 1
        : plus
        ? access['maxActiveDisplays']
        : access['displayLimit'] ?? 3,
    'pilotEndsAt': !free && until > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            until,
            isUtc: true,
          ).toIso8601String()
        : null,
  };
}
