import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/domain/usecases/billing_actions.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
part 'billing_controller.g.dart';

@riverpod
Future<BillingStatus> billingStatus(Ref ref) async {
  final uid = ref.watch(authStateProvider.select((value) => value.value?.id));
  if (uid == null) return const BillingStatus();
  return ref.watch(billingActionsProvider).load();
}

@riverpod
Future<List<BillingOffer>> billingOffers(Ref ref) async {
  final status = await ref.watch(billingStatusProvider.future);
  if (!status.purchasesEnabled) return [];
  return ref.watch(billingActionsProvider).offers(status.productIds);
}

@Riverpod(keepAlive: true)
class BillingPurchaseController extends _$BillingPurchaseController {
  final _unverified = <String, StorePurchase>{};
  Future<void> _queue = Future.value();
  bool _recovering = false;
  @override
  BillingActivity build() {
    final actions = ref.watch(billingActionsProvider);
    final subscription = actions.events.listen(
      (events) {
        _queue = _queue.then((_) async {
          for (final event in events) {
            if (ref.mounted) await _handle(event);
          }
        });
      },
      onError: (Object _) {
        if (ref.mounted) {
          state = const BillingActivity(
            needsVerification: true,
            message: '스토어 연결을 확인한 뒤 구매를 복원해 주세요.',
            error: true,
          );
        }
      },
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    ref.listen(authStateProvider, (before, after) {
      if (before?.value?.id != after.value?.id) {
        state = BillingActivity(needsVerification: _unverified.isNotEmpty);
        if (after.value != null) {
          unawaited(retry());
          unawaited(recoverPendingPurchases());
        }
      }
    });
    return const BillingActivity();
  }

  Future<void> recoverPendingPurchases() async {
    if (_recovering ||
        ref.read(authStateProvider).value == null ||
        ref.read(billingActionsProvider).store != 'google_play') {
      return;
    }
    _recovering = true;
    // Query Play on foreground/login to recover approvals completed outside the
    // app. A network failure never changes access or blocks the editor.
    await AsyncValue.guard(
      () => ref.read(billingActionsProvider).recoverPendingPurchases(),
    );
    _recovering = false;
  }

  Future<void> _handle(StorePurchase purchase) async {
    if (purchase.phase == StorePurchasePhase.pending) {
      state = BillingActivity(
        busy: purchase.store != 'google_play',
        needsVerification: true,
        message: '스토어 결제 승인을 기다리고 있어요.',
      );
      return;
    }
    if (purchase.phase == StorePurchasePhase.canceled ||
        purchase.phase == StorePurchasePhase.error) {
      state = BillingActivity(
        needsVerification: _unverified.isNotEmpty,
        message: purchase.phase == StorePurchasePhase.canceled
            ? '결제를 취소했어요.'
            : purchase.error,
        error: purchase.phase == StorePurchasePhase.error,
      );
      return;
    }
    _unverified[purchase.key] = purchase;
    final uid = ref.read(authStateProvider).value?.id;
    if (uid == null) {
      state = const BillingActivity(needsVerification: true);
      return;
    }
    state = const BillingActivity(
      busy: true,
      needsVerification: true,
      message: '구독을 안전하게 확인하고 있어요.',
    );
    final result = await AsyncValue.guard(
      () => ref.read(billingActionsProvider).verify(purchase),
    );
    if (!ref.mounted) return;
    if (!result.hasError) _unverified.remove(purchase.key);
    if (ref.read(authStateProvider).value?.id != uid) return;
    state = BillingActivity(
      needsVerification: _unverified.isNotEmpty,
      message: result.hasError
          ? '${result.error}\n다시 결제하지 말고 아래에서 확인을 재시도해 주세요.'
          : result.value ?? '구독 상태를 확인했어요.',
      error: result.hasError,
    );
    ref.invalidate(billingStatusProvider);
    ref.invalidate(userProfileControllerProvider);
  }

  Future<void> retry() async {
    if (state.busy) return;
    if (_unverified.isEmpty) await recoverPendingPurchases();
    _queue = _queue.then((_) async {
      for (final purchase in _unverified.values.toList()) {
        if (ref.mounted) await _handle(purchase);
      }
    });
    await _queue;
  }

  Future<void> purchase(String id) async {
    if (state.busy || state.needsVerification) return;
    state = const BillingActivity(busy: true, message: '스토어 결제 화면을 여는 중이에요.');
    final result = await AsyncValue.guard(
      () => ref.read(billingActionsProvider).purchase(id),
    );
    if (ref.mounted && result.hasError) {
      state = BillingActivity(message: '${result.error}', error: true);
    }
  }

  Future<void> restore() async {
    if (state.busy) return;
    state = BillingActivity(
      busy: true,
      needsVerification: _unverified.isNotEmpty,
      message: '구매 내역을 확인하고 있어요.',
    );
    final result = await AsyncValue.guard(
      () => ref.read(billingActionsProvider).restore(),
    );
    await _queue;
    if (!ref.mounted) return;
    if (result.hasError) {
      state = BillingActivity(
        needsVerification: _unverified.isNotEmpty,
        message: '${result.error}',
        error: true,
      );
    } else if (state.busy) {
      state = BillingActivity(
        needsVerification: _unverified.isNotEmpty,
        message: '복원을 요청했어요. 구독 내역이 있으면 확인 후 반영됩니다.',
      );
    }
    ref.invalidate(billingStatusProvider);
  }

  Future<void> refresh() async {
    if (state.busy) return;
    state = BillingActivity(
      busy: true,
      needsVerification: _unverified.isNotEmpty,
    );
    final result = await AsyncValue.guard(
      () => ref.read(billingActionsProvider).load(refresh: true),
    );
    if (!ref.mounted) return;
    state = BillingActivity(
      needsVerification: _unverified.isNotEmpty,
      message: result.hasError ? '${result.error}' : '최신 이용 상태를 확인했어요.',
      error: result.hasError,
    );
    ref.invalidate(billingStatusProvider);
  }
}
