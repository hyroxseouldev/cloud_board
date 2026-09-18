import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/usecases/entitlement_actions.dart';
part 'entitlement_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<StoreEntitlement?> storeEntitlement(Ref ref) {
  final user = ref.watch(firebaseAccountUserProvider).value;
  if (user == null || user.isAnonymous) return Stream.value(null);
  return ref.watch(entitlementActionsProvider).watch(user.uid);
}

@Riverpod(keepAlive: true)
Stream<bool> entitlementConnection(Ref ref) =>
    ref.watch(entitlementActionsProvider).watchConnection();

@Riverpod(keepAlive: true)
Future<String> storeAccountLink(Ref ref) async {
  final user = ref.watch(firebaseAccountUserProvider).value;
  if (user == null || user.isAnonymous) return 'signed_out';
  if (ref.watch(entitlementConnectionProvider).value != true) {
    return 'connection_unavailable';
  }
  if (!user.providerData.any((p) => p.providerId == 'google.com')) {
    return 'google_required';
  }
  return ref.watch(entitlementActionsProvider).link();
}
