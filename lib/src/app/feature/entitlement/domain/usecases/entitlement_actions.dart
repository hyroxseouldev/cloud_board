import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/repositories/entitlement_repository_impl.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
part 'entitlement_actions.g.dart';

class EntitlementActions {
  EntitlementActions(this.repository);
  final EntitlementRepository repository;
  Stream<StoreEntitlement> watch(String uid) => repository.watch(uid);
  Stream<bool> watchConnection() => repository.watchConnection();
  Future<String> link() => repository.link();
}

@riverpod
EntitlementActions entitlementActions(Ref ref) =>
    EntitlementActions(ref.watch(entitlementRepositoryProvider));
