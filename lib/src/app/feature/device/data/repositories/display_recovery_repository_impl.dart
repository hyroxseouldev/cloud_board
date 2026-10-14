import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/display_recovery_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_recovery_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'display_recovery_repository_impl.g.dart';

class DisplayRecoveryRepositoryImpl implements DisplayRecoveryRepository {
  const DisplayRecoveryRepositoryImpl(this.source);
  final DisplayRecoveryDataSource source;
  @override
  Stream<DisplayRecoveryRequest?> watch(String deviceId) =>
      source.watch(deviceId);
  @override
  Future<DisplayRecoveryRequest> request(String deviceId, String operationId) =>
      source.request(deviceId, operationId);
  @override
  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  }) => source.report(
    request,
    status,
    sessionId: sessionId,
    revision: revision,
    errorCode: errorCode,
  );
}

@riverpod
DisplayRecoveryRepository displayRecoveryRepository(Ref ref) {
  final owner = ref.watch(accountOwnerIdProvider);
  final ownerId = owner.isLoading || owner.hasError ? null : owner.value;
  final app = FirebaseAuth.instance.app;
  final source = DisplayRecoveryDataSource(
    FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: cloudBoardRealtimeDatabaseUrl,
    ),
    FirebaseFunctions.instanceFor(app: app, region: 'asia-northeast3'),
    ownerId,
  );
  ref.onDispose(source.dispose);
  return DisplayRecoveryRepositoryImpl(source);
}
