import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';

class BillingDataSource {
  String? get accountId => FirebaseAuth.instance.currentUser?.uid;
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);
  String get store => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'google_play'
      : 'app_store';
  String get storeLabel => store == 'google_play' ? 'Google Play' : 'App Store';
  String get endpoint =>
      store == 'google_play' ? 'cloudboardPlayBilling' : 'cloudboardBilling';
  final _purchases = <String, PurchaseDetails>{};
  final _products = <String, ProductDetails>{};

  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    try {
      return (await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable(
                endpoint,
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120),
                ),
              )
              .call<Map<String, dynamic>>(input))
          .data;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? '구독을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  Stream<List<StorePurchase>> get events => supported
      ? InAppPurchase.instance.purchaseStream.map(
          (items) => items.map((item) {
            // A Play token identifies the purchase across renewals; order IDs may
            // be absent. The token is kept in memory only and sent to our server.
            final key = store == 'google_play'
                ? item.verificationData.serverVerificationData
                : item.purchaseID ?? item.productID;
            _purchases[key] = item;
            return StorePurchase(
              key: key,
              phase: StorePurchasePhase.values.byName(item.status.name),
              signedTransaction: item.verificationData.serverVerificationData,
              store: store,
              error: item.error == null
                  ? null
                  : '$storeLabel에서 요청을 완료하지 못했습니다. 다시 시도해 주세요.',
            );
          }).toList(),
        )
      : const Stream.empty();

  Future<List<BillingOffer>> offers(List<String> ids) async {
    if (!supported) return [];
    if (!await InAppPurchase.instance.isAvailable()) {
      throw StateError('$storeLabel에 연결할 수 없습니다.');
    }
    final response = await InAppPurchase.instance.queryProductDetails(
      ids.toSet(),
    );
    if (response.error != null) throw StateError('구독 상품을 불러오지 못했습니다.');
    _products.clear();
    for (final item in response.productDetails) {
      if (!ids.contains(item.id)) continue;
      if (store == 'google_play' && !isMonthlyPlayProduct(item)) continue;
      _products[item.id] = item;
    }
    return _products.values
        .map((p) => BillingOffer(id: p.id, price: p.price))
        .toList();
  }

  Future<void> buy(String productId, String token) async {
    final product = _products[productId];
    if (!supported || product == null) throw StateError('구독 상품을 다시 불러와 주세요.');
    final launched = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: product is GooglePlayProductDetails
          ? GooglePlayPurchaseParam(
              productDetails: product,
              applicationUserName: token,
              offerToken: product.offerToken,
            )
          : PurchaseParam(productDetails: product, applicationUserName: token),
    );
    if (!launched) throw StateError('$storeLabel 결제 화면을 열지 못했습니다.');
  }

  Future<void> restore(String token) async {
    if (!supported) throw StateError('구입한 스토어의 모바일 기기에서 복원해 주세요.');
    await InAppPurchase.instance.restorePurchases(applicationUserName: token);
  }

  Future<void> recoverPendingPurchases() async {
    if (supported &&
        store == 'google_play' &&
        await InAppPurchase.instance.isAvailable()) {
      await InAppPurchase.instance.restorePurchases();
    }
  }

  Future<void> complete(String key) async {
    final item = _purchases[key];
    // Play acknowledgements are committed on the backend (including RTDN).
    // Re-acknowledging a stale client PurchaseDetails would race that operation.
    if (store != 'google_play' && item?.pendingCompletePurchase == true) {
      await InAppPurchase.instance.completePurchase(item!);
    }
    _purchases.remove(key);
  }
}

bool isMonthlyPlayProduct(ProductDetails product) {
  if (product is! GooglePlayProductDetails) return false;
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index >= offers.length) return false;
  final offer = offers[index];
  return offer.basePlanId == 'monthly' &&
      offer.offerId == null &&
      offer.installmentPlanDetails == null &&
      offer.pricingPhases.length == 1 &&
      offer.pricingPhases.single.billingPeriod == 'P1M' &&
      offer.pricingPhases.single.recurrenceMode ==
          RecurrenceMode.infiniteRecurring;
}
