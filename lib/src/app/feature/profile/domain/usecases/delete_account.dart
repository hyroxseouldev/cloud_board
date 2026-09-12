import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/profile/data/repositories/account_deletion_repository_impl.dart';
part 'delete_account.g.dart';

class DeleteAccount {
  const DeleteAccount(this.repository);
  final AccountDeletionRepository repository;
  Future<AccountDeletionResult> call() => repository.deleteAccount();
}

@riverpod
DeleteAccount deleteAccount(Ref ref) =>
    DeleteAccount(ref.watch(accountDeletionRepositoryProvider));
