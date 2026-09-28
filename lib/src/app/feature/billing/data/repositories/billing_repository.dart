import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/billing/data/datasources/billing_data_source.dart';
import 'package:cloud_board/src/app/feature/billing/data/models/billing_model.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/domain/repositories/billing_repository.dart';
part 'billing_repository.g.dart';

class FirebaseBillingRepository implements BillingRepository {
  FirebaseBillingRepository(this.source);
  final BillingDataSource source;
  @override
  bool get storeSupported => source.supported;
  @override
  Stream<List<StorePurchase>> get events => source.events;
  @override
  Future<BillingStatus> load({bool refresh = false}) async =>
      BillingModel.fromJson(
        await source.call({'action': refresh ? 'refresh' : 'load'}),
      ).toEntity();
  @override
  Future<List<BillingOffer>> offers(List<String> ids) => source.offers(ids);
  @override
  Future<void> purchase(String id) async {
    final uid = source.accountId;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    final response = await source.call({'action': 'prepare', 'productId': id});
    if (source.accountId != uid) {
      throw StateError('로그인 계정이 변경되었습니다. 다시 시도해 주세요.');
    }
    await source.buy(id, response['appAccountToken'] as String);
  }

  @override
  Future<void> restore() async {
    final uid = source.accountId;
    final status = await load();
    if (uid == null || source.accountId != uid) {
      throw StateError('로그인 계정이 변경되었습니다. 다시 시도해 주세요.');
    }
    await source.restore(status.appAccountToken);
  }

  @override
  Future<String?> verifyAndComplete(StorePurchase purchase) async {
    final response = await source.call({
      'action': 'verify',
      'signedTransaction': purchase.signedTransaction,
    });
    if (response['verified'] != true) throw StateError('구독 확인을 다시 시도해 주세요.');
    // Never finish a purchase until the server has committed ownership and access.
    await source.complete(purchase.key);
    return response['retired'] == true
        ? '삭제한 계정의 이전 구매를 정리했어요. 자동 갱신은 Apple 구독 관리에서 별도로 해지해 주세요.'
        : null;
  }
}

@Riverpod(keepAlive: true)
BillingRepository billingRepository(Ref ref) =>
    FirebaseBillingRepository(BillingDataSource());
