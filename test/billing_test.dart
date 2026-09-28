import 'dart:async';

import 'package:flutter/material.dart';
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
  Completer<Map<String, dynamic>> response = Completer();
  int finishes = 0;
  int purchases = 0;
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
  Stream<List<StorePurchase>> get events => const Stream.empty();
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) =>
      response.future;
  @override
  Future<void> complete(String key) async {
    finishes++;
  }
}

void main() {
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
  for (final size in [const Size(320, 568), const Size(834, 1194)]) {
    testWidgets(
      'disabled subscription keeps restore and never offers a guessed price at $size',
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
                  FirebaseBillingRepository(FakeBillingSource()),
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
      },
    );
  }
}
