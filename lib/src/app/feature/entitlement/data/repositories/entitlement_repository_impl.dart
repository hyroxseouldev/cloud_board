import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/datasources/entitlement_data_source.dart';
part 'entitlement_repository_impl.g.dart';

class EntitlementRepositoryImpl implements EntitlementRepository {
  EntitlementRepositoryImpl(this.source);
  final EntitlementDataSource source;
  @override
  Stream<bool> watchConnection() => source.watchConnection();
  @override
  Stream<StoreEntitlement> watch(String uid) => source.watch(uid);
  @override
  Future<String> link() => source.link();
}

@riverpod
EntitlementRepository entitlementRepository(Ref ref) =>
    EntitlementRepositoryImpl(EntitlementDataSource());
