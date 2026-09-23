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
    };
  }
  final until = (access['validUntilMs'] as num?)?.toInt() ?? 0;
  final valid = until > nowMs;
  final premium =
      access['plan'] == 'premium' && access['displaysUnlimited'] == true;
  final plus =
      access['plan'] == 'plus' &&
      access['maxActiveDisplays'] == 1 &&
      access['displaysUnlimited'] == false;
  final status = access['status'];
  return {
    ...?profile,
    'partnerTier': !valid
        ? 'free'
        : status == 'trialing'
        ? 'trial'
        : 'pro',
    'subscriptionPlan': !valid
        ? 'free'
        : premium
        ? 'premium'
        : plus
        ? 'plus'
        : 'cloudboard_pro',
    'subscriptionStatus': !valid
        ? 'canceled'
        : status == 'trialing'
        ? 'trialing'
        : status == 'past_due'
        ? 'pastDue'
        : 'active',
    'displayLimit': premium
        ? -1
        : plus
        ? 1
        : access['displayLimit'] ?? 3,
    'pilotEndsAt': until > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            until,
            isUtc: true,
          ).toIso8601String()
        : null,
  };
}
