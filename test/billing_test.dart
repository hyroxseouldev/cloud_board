import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/billing/data/datasources/billing_data_source.dart';
import 'package:cloud_board/src/app/feature/billing/data/repositories/billing_repository.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/domain/usecases/billing_actions.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/controllers/billing_controller.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/views/subscription_screen.dart';

class FakeBillingSource extends BillingDataSource {
  FakeBillingSource({
    this.billingStore = 'app_store',
    this.eventStream = const Stream.empty(),
  });
  final String billingStore;
  final Stream<List<StorePurchase>> eventStream;
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> response = Completer();
  int finishes = 0;
  int purchases = 0;
  int recoveries = 0;
  String? uid = 'owner';
  @override
  String? get accountId => uid;
  @override
  Future<void> buy(String productId, String token) async {
    purchases++;
  }

  @override
  bool get supported => true;
  @override
  String get store => billingStore;
  @override
  Future<void> recoverPendingPurchases() async {
    recoveries++;
  }

  @override
  Stream<List<StorePurchase>> get events => eventStream;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) {
    calls.add(input);
    return response.future;
  }

  @override
  Future<void> complete(String key) async {
    finishes++;
  }
}

void main() {
  testWidgets(
    'Play pending approval allows recovery and finishes only after verified approval',
    (tester) async {
      final events = StreamController<List<StorePurchase>>.broadcast();
      final source = FakeBillingSource(
        billingStore: 'google_play',
        eventStream: events.stream,
      );
      final container = ProviderContainer.test(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'owner',
                email: '',
                displayName: '',
                photoUrl: null,
              ),
            ),
          ),
          billingActionsProvider.overrideWith(
            (ref) => BillingActions(FirebaseBillingRepository(source)),
          ),
        ],
      );
      container.listen(billingPurchaseControllerProvider, (_, _) {});
      await container.read(authStateProvider.future);
      await tester.pump();
      events.add([
        const StorePurchase(
          key: 'google-token',
          phase: StorePurchasePhase.pending,
          signedTransaction: 'google-token',
          store: 'google_play',
        ),
      ]);
      await tester.pump();
      expect(container.read(billingPurchaseControllerProvider).busy, isFalse);
      expect(
        container.read(billingPurchaseControllerProvider).needsVerification,
        isTrue,
      );
      expect(source.finishes, 0);
      final before = source.recoveries;
      await container.read(billingPurchaseControllerProvider.notifier).retry();
      expect(source.recoveries, greaterThan(before));
      source.response.complete({'verified': true});
      events.add([
        const StorePurchase(
          key: 'google-token',
          phase: StorePurchasePhase.restored,
          signedTransaction: 'google-token',
          store: 'google_play',
        ),
      ]);
      await tester.pump();
      expect(source.finishes, 1);
      expect(
        container.read(billingPurchaseControllerProvider).needsVerification,
        isFalse,
      );
      await events.close();
    },
  );
  test('Android and iOS route to their own server endpoint', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final source = BillingDataSource();
      expect(source.supported, isTrue);
      expect(
        source.endpoint,
        platform == TargetPlatform.android
            ? 'cloudboardPlayBilling'
            : 'cloudboardBilling',
      );
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(BillingDataSource().supported, isFalse);
  });
  test('Play verification sends purchase token and never an Apple signed transaction', () async {
    final source = FakeBillingSource(billingStore: 'google_play');
    final result = FirebaseBillingRepository(source).verifyAndComplete(
      const StorePurchase(
        key: 'google-token',
        phase: StorePurchasePhase.restored,
        signedTransaction: 'google-token',
        store: 'google_play',
      ),
    );
    expect(source.calls.single, {
      'action': 'verify',
      'purchaseToken': 'google-token',
    });
    expect(source.finishes, 0);
    source.response.complete({'verified': true});
    await result;
    expect(source.finishes, 1);
  });
  test('only the regular auto-renewing monthly base plan is offered, never intro/annual/prepaid', () {
    SubscriptionOfferDetailsWrapper offer(
      String id, {
      String? intro,
      String period = 'P1M',
      RecurrenceMode mode = RecurrenceMode.infiniteRecurring,
    }) => SubscriptionOfferDetailsWrapper(
      basePlanId: id,
      offerId: intro,
      offerTags: [],
      offerIdToken: id,
      pricingPhases: [
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: period,
          formattedPrice: '₩1,000',
          priceAmountMicros: 1000000000,
          priceCurrencyCode: 'KRW',
          recurrenceMode: mode,
        ),
      ],
    );
    final products = GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        description: '',
        name: 'Plus',
        productId: 'com.sunmkim.cloudboard.plus.monthly',
        productType: ProductType.subs,
        title: 'Plus',
        subscriptionOfferDetails: [
          offer('monthly'),
          offer('annual', period: 'P1Y'),
          offer('monthly', intro: 'free-trial'),
          offer('monthly', mode: RecurrenceMode.nonRecurring),
        ],
      ),
    );
    expect(products.map(isMonthlyPlayProduct), [true, false, false, false]);
  });
  test('account change while preparing prevents opening a purchase for the old account', () async {
    final source = FakeBillingSource(),
        repository = FirebaseBillingRepository(FakeBillingSource());
    expect(repository.storeSupported, isTrue);
    final pending = FirebaseBillingRepository(source).purchase('plus');
    source.uid = 'other';
    source.response.complete({'appAccountToken': 'old-token'});
    await expectLater(pending, throwsStateError);
    expect(source.purchases, 0);
  });
  test('purchase completion waits for committed server verification; failure stays retryable', () async {
    final source = FakeBillingSource(),
        purchase = const StorePurchase(
          key: '123',
          phase: StorePurchasePhase.purchased,
          signedTransaction: 'jws',
        );
    final repository = FirebaseBillingRepository(source);
    final failed = repository.verifyAndComplete(purchase);
    expect(source.finishes, 0);
    source.response.complete({'verified': false});
    await expectLater(failed, throwsStateError);
    expect(source.finishes, 0);
    source.response = Completer();
    final retry = repository.verifyAndComplete(purchase);
    source.response.complete({'verified': true});
    await retry;
    expect(source.finishes, 1);
  });
  for (final store in ['app_store', 'google_play']) {
    for (final size in [const Size(320, 568), const Size(834, 1194)]) {
      testWidgets(
        '$store disabled subscription keeps restore and never offers a guessed price at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authStateProvider.overrideWith(
                  (ref) => Stream.value(
                    const AuthUser(
                      id: 'owner',
                      email: '',
                      displayName: '',
                      photoUrl: null,
                    ),
                  ),
                ),
                billingActionsProvider.overrideWith(
                  (ref) => BillingActions(
                    FirebaseBillingRepository(
                      FakeBillingSource(billingStore: store),
                    ),
                  ),
                ),
                billingStatusProvider.overrideWith(
                  (ref) async =>
                      const BillingStatus(plan: 'premium', status: 'trialing'),
                ),
                billingOffersProvider.overrideWith((ref) async => []),
              ],
              child: const MaterialApp(home: SubscriptionScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('무료 체험 중'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('구매 복원'), 250);
          expect(
            tester
                .widget<TextButton>(
                  find.ancestor(
                    of: find.text('구매 복원'),
                    matching: find.byType(TextButton),
                  ),
                )
                .onPressed,
            isNotNull,
          );
          expect(
            tester
                .widgetList<FilledButton>(find.byType(FilledButton))
                .every((b) => b.onPressed == null),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          final label = store == 'google_play'
              ? 'Google Play 구독 관리'
              : 'Apple 구독 관리';
          await tester.scrollUntilVisible(find.text(label), 150);
          expect(find.text(label), findsOneWidget);
        },
      );
    }
  }
}
