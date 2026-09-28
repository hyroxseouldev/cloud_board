import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/domain/usecases/billing_actions.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/controllers/billing_controller.dart';

const appleSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';
const subscriptionTermsUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const subscriptionPrivacyUrl =
    'https://clyr-landing-20.vercel.app/apps/cloudboard/privacy';

class SubscriptionScreen extends HookConsumerWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(billingStatusProvider);
    final activity = ref.watch(billingPurchaseControllerProvider);
    final actions = ref.read(billingPurchaseControllerProvider.notifier);
    final supported = ref.watch(billingActionsProvider).storeSupported;
    final offers = ref.watch(billingOffersProvider);
    useOnAppLifecycleStateChange((previous, next) {
      if (next == AppLifecycleState.resumed) {
        ref.invalidate(billingStatusProvider);
      }
    });
    Future<void> open(String url) async {
      var launched = false;
      try {
        launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('페이지를 열 수 없습니다. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }

    String date(int ms) {
      final value = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 구독'),
        actions: [
          IconButton(
            onPressed: activity.busy ? null : actions.refresh,
            tooltip: '이용 상태 새로고침',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AsyncValueWidget<BillingStatus>(
        value: status,
        onRetry: () => ref.invalidate(billingStatusProvider),
        data: (data) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                Text(
                  '우리 센터에 맞는\n수업의 다음 단계.',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.statusLabel,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.planLabel,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (data.validUntilMs > 0) ...[
                          const SizedBox(height: 8),
                          Text('${date(data.validUntilMs)}까지 이용'),
                        ],
                        if (data.status == 'trialing') ...[
                          const SizedBox(height: 12),
                          const Text(
                            '1개월 무료 체험은 자동으로 결제되지 않아요.\n유료 구독을 선택하면 바로 결제가 시작되며, 남은 체험 기간이 유료 구독 기간에 더해지지는 않아요.',
                          ),
                        ],
                        if (data.paidStatus != null) ...[
                          const Divider(height: 32),
                          Text(
                            data.autoRenew
                                ? 'App Store 자동 갱신 켜짐'
                                : 'App Store 자동 갱신 꺼짐',
                          ),
                          if (data.paidExpiresAtMs > 0)
                            Text('결제 이용 기간 · ${date(data.paidExpiresAtMs)}까지'),
                          if (data.nextProductId != null &&
                              !data.nextProductId!.contains(
                                '.${data.paidPlan}.',
                              ))
                            Text(
                              '다음 갱신부터 ${data.nextProductId!.contains('.premium.') ? '프리미엄' : '플러스'} 적용 예정',
                            ),
                          if ([
                            'billing_retry',
                            'grace_period',
                          ].contains(data.paidStatus))
                            const Text('Apple 구독 관리에서 결제 수단을 확인해 주세요.'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!data.purchasesEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      data.paidStatus != null
                          ? '기존 구독의 변경·해지는 Apple 구독 관리에서 할 수 있어요.'
                          : '유료 구독은 준비 중이에요. 기존 이용 권한과 무료 체험은 그대로 유지돼요.',
                    ),
                  ),
                if (!supported)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      '연결된 계정의 구독은 모든 기기에서 적용돼요. Apple 구매 복원은 iPhone 또는 iPad에서 진행해 주세요.',
                    ),
                  ),
                for (final plan in ['plus', 'premium']) ...[
                  _PlanCard(
                    plan: plan,
                    offer: offers.value
                        ?.where((o) => o.id.contains('.$plan.'))
                        .firstOrNull,
                    enabled:
                        supported &&
                        data.purchasesEnabled &&
                        !activity.busy &&
                        !activity.needsVerification,
                    onPurchase: actions.purchase,
                  ),
                  const SizedBox(height: 12),
                ],
                if (offers.hasError)
                  TextButton(
                    onPressed: () => ref.invalidate(billingOffersProvider),
                    child: const Text('상품 정보를 다시 불러오기'),
                  ),
                if (activity.busy) const LinearProgressIndicator(),
                if (activity.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        activity.message!,
                        style: TextStyle(
                          color: activity.error
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ),
                if (activity.needsVerification)
                  OutlinedButton(
                    onPressed: activity.busy ? null : actions.retry,
                    child: const Text('결제 확인 다시 시도'),
                  ),
                if (supported)
                  TextButton.icon(
                    onPressed: activity.busy ? null : actions.restore,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('구매 복원'),
                  ),
                if (supported || data.paidStatus != null)
                  TextButton.icon(
                    onPressed: () => open(appleSubscriptionsUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Apple 구독 관리'),
                  ),
                const SizedBox(height: 16),
                const Text(
                  '유료 구독은 매월 자동 갱신됩니다. 결제 금액과 갱신 조건은 App Store 결제 화면에서 확인할 수 있어요. '
                  '해지는 Apple 구독 관리에서 언제든 할 수 있으며, 해지해도 이미 결제한 기간까지 이용할 수 있어요.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => open(subscriptionTermsUrl),
                      child: const Text('이용약관'),
                    ),
                    TextButton(
                      onPressed: () => open(subscriptionPrivacyUrl),
                      child: const Text('개인정보처리방침'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.offer,
    required this.enabled,
    required this.onPurchase,
  });
  final String plan;
  final BillingOffer? offer;
  final bool enabled;
  final Future<void> Function(String) onPurchase;
  @override
  Widget build(BuildContext context) {
    final premium = plan == 'premium';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            premium ? '프리미엄' : '플러스',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(premium ? '센터 디스플레이·즐겨찾기 제한 없이' : '디스플레이 1대 · 즐겨찾기 3개'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: enabled && offer != null
                ? () => onPurchase(offer!.id)
                : null,
            child: Text(
              offer == null ? '구독 준비 중' : '${offer!.price} / 월 · 구독하기',
            ),
          ),
        ],
      ),
    );
  }
}
