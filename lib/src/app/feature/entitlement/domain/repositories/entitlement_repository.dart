import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';

abstract class EntitlementRepository {
  Stream<StoreEntitlement> watch(String uid);
  Future<String> link();
  Stream<bool> watchConnection();
}
