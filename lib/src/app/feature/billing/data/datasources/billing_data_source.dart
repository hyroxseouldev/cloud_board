import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';

class BillingDataSource {
  String? get accountId => FirebaseAuth.instance.currentUser?.uid;
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final _purchases = <String, PurchaseDetails>{};
  final _products = <String, ProductDetails>{};

  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    try {
      return (await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable(
                'cloudboardBilling',
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
            final key = item.purchaseID ?? item.productID;
            _purchases[key] = item;
            return StorePurchase(
              key: key,
              phase: StorePurchasePhase.values.byName(item.status.name),
              signedTransaction: item.verificationData.serverVerificationData,
              error: item.error == null
                  ? null
                  : 'App Store에서 요청을 완료하지 못했습니다. 다시 시도해 주세요.',
            );
          }).toList(),
        )
      : const Stream.empty();

  Future<List<BillingOffer>> offers(List<String> ids) async {
    if (!supported) return [];
    if (!await InAppPurchase.instance.isAvailable()) {
      throw StateError('App Store에 연결할 수 없습니다.');
    }
    final response = await InAppPurchase.instance.queryProductDetails(
      ids.toSet(),
    );
    if (response.error != null) throw StateError('구독 상품을 불러오지 못했습니다.');
    _products.clear();
    for (final item in response.productDetails) {
      _products[item.id] = item;
    }
    return response.productDetails
        .map((p) => BillingOffer(id: p.id, price: p.price))
        .toList();
  }

  Future<void> buy(String productId, String token) async {
    final product = _products[productId];
    if (!supported || product == null) throw StateError('구독 상품을 다시 불러와 주세요.');
    final launched = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: token,
      ),
    );
    if (!launched) throw StateError('App Store 결제 화면을 열지 못했습니다.');
  }

  Future<void> restore(String token) async {
    if (!supported) throw StateError('구입한 iPhone 또는 iPad에서 복원해 주세요.');
    await InAppPurchase.instance.restorePurchases(applicationUserName: token);
  }

  Future<void> complete(String key) async {
    final item = _purchases[key];
    if (item?.pendingCompletePurchase == true) {
      await InAppPurchase.instance.completePurchase(item!);
    }
    _purchases.remove(key);
  }
}
