import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/profile/domain/usecases/delete_account.dart';
part 'account_deletion_controller.g.dart';

@Riverpod(keepAlive: true)
class AccountDeletionController extends _$AccountDeletionController {
  @override
  AsyncValue<AccountDeletionResult?> build() => const AsyncData(null);

  Future<void> deleteAccount() async {
    if (state.isLoading || state.value == AccountDeletionResult.processing) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(deleteAccountProvider).call();
    });
  }
}
