import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cloud_board/src/app/feature/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';

part 'account_deletion_repository_impl.g.dart';

class FirebaseAccountDeletionRepository implements AccountDeletionRepository {
  const FirebaseAccountDeletionRepository(
    this.auth,
    this.functions,
    this.clearLocal,
  );
  final FirebaseAuthDataSource auth;
  final FirebaseFunctions functions;
  final Future<void> Function() clearLocal;

  @override
  Future<AccountDeletionResult> deleteAccount() async {
    await auth.reauthenticateWithGoogle();
    try {
      final response = await functions
          .httpsCallable(
            'deleteMyAccount',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
          )
          .call<Map<String, dynamic>>({'confirm': true});
      final status = response.data['status'];
      if (status == 'processing') return AccountDeletionResult.processing;
      if (status != 'completed') throw StateError('삭제 결과를 확인하지 못했습니다.');
      // Only clear the session after the server confirms all account data deletion.
      try {
        await clearLocal();
      } finally {
        await auth.signOut();
      }
      return AccountDeletionResult.completed;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' || error.code == 'unimplemented') {
        throw StateError(
          '계정 삭제 서비스를 사용할 수 없습니다. 잠시 후 다시 시도하거나 vividxxxxx@gmail.com으로 문의해 주세요.',
        );
      }
      throw StateError(
        '삭제 결과를 확인하지 못했습니다. 계정을 다시 만들지 말고 vividxxxxx@gmail.com으로 문의해 주세요.',
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }
}

@riverpod
AccountDeletionRepository accountDeletionRepository(Ref ref) {
  final playback = ref.watch(playbackSessionLocalDataSourceProvider);
  final workouts = ref.watch(workoutLocalDataSourceProvider.future);
  return FirebaseAccountDeletionRepository(
    ref.watch(firebaseAuthDataSourceProvider),
    FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
    () async {
      await playback.clear();
      await (await workouts).clear();
    },
  );
}
