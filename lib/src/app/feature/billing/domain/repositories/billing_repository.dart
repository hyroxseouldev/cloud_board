import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';

abstract interface class BillingRepository {
  bool get storeSupported;
  String get store;
  Stream<List<StorePurchase>> get events;
  Future<BillingStatus> load({bool refresh = false});
  Future<List<BillingOffer>> offers(List<String> ids);
  Future<void> purchase(String id);
  Future<void> restore();
  Future<void> recoverPendingPurchases();
  Future<String?> verifyAndComplete(StorePurchase purchase);
}
