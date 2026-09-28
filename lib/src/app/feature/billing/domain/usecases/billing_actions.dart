import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/billing/domain/repositories/billing_repository.dart';
import 'package:cloud_board/src/app/feature/billing/data/repositories/billing_repository.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
part 'billing_actions.g.dart';

class BillingActions {
  const BillingActions(this.repository);
  final BillingRepository repository;
  bool get storeSupported => repository.storeSupported;
  Stream<List<StorePurchase>> get events => repository.events;
  Future<BillingStatus> load({bool refresh = false}) =>
      repository.load(refresh: refresh);
  Future<List<BillingOffer>> offers(List<String> ids) => repository.offers(ids);
  Future<void> purchase(String id) => repository.purchase(id);
  Future<void> restore() => repository.restore();
  Future<String?> verify(StorePurchase purchase) =>
      repository.verifyAndComplete(purchase);
}

@Riverpod(keepAlive: true)
BillingActions billingActions(Ref ref) =>
    BillingActions(ref.watch(billingRepositoryProvider));
