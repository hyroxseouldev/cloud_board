// Historical receipt/wire compatibility only; never a sellable offering or
// an inferred image-usage policy plan. Keep individually assigned paid rights.
const historicalPaidWirePlan = 'plus';
bool isHistoricalPaidPlan(String? plan) => plan == historicalPaidWirePlan;
const historicalSubscriptionLabel = '기존 구독 이용 중';
bool historicalDisplayPolicy(Map<String, dynamic> access) =>
    isHistoricalPaidPlan(access['plan'] as String?) &&
    (access['maxActiveDisplays'] == 1 || access['maxActiveDisplays'] == 3) &&
    access['displaysUnlimited'] == false;
