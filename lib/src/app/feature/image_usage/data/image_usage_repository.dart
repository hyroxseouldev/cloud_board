import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';

// Recreated only with the account scope, never a token/profile refresh. Retained
// pending requests are namespaced by actor; disposal fences all late responses.
final imageUsageSourceProvider = Provider.autoDispose<ImageUsageDataSource>((
  ref,
) {
  final auth = ref.watch(firebaseClientAuthProvider);
  final owner = ref.watch(accountOwnerIdProvider);
  ref.watch(
    firebaseAccountUserProvider.select(
      (value) => (value.value?.uid, value.value?.isAnonymous),
    ),
  );
  if (owner.isLoading || owner.hasError || owner.value == null) {
    throw StateError('연결된 계정을 확인해 주세요.');
  }
  final source = ImageUsageDataSource.forApp(auth.app, auth: auth);
  ref.onDispose(source.dispose);
  return source;
});
