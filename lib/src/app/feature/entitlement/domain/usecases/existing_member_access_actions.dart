import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/repositories/existing_member_access_repository.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/repositories/existing_member_access_repository.dart';
part 'existing_member_access_actions.g.dart';

class ExistingMemberAccessActions {
  ExistingMemberAccessActions(this.repository);
  final ExistingMemberAccessRepository repository;
  Stream<bool> watch(String uid) => repository.watch(uid);
}

@riverpod
ExistingMemberAccessActions existingMemberAccessActions(Ref ref) =>
    ExistingMemberAccessActions(
      ref.watch(existingMemberAccessRepositoryProvider),
    );
