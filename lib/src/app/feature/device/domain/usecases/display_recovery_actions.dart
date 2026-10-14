import 'package:cloud_board/src/app/feature/device/data/repositories/display_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_recovery_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'display_recovery_actions.g.dart';

class DisplayRecoveryActions {
  const DisplayRecoveryActions(this.repository);
  final DisplayRecoveryRepository repository;
  Stream<DisplayRecoveryRequest?> watch(String deviceId) =>
      repository.watch(deviceId);
  Future<DisplayRecoveryRequest> request(String deviceId, String operationId) =>
      repository.request(deviceId, operationId);
  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  }) => repository.report(
    request,
    status,
    sessionId: sessionId,
    revision: revision,
    errorCode: errorCode,
  );
}

@riverpod
DisplayRecoveryActions displayRecoveryActions(Ref ref) =>
    DisplayRecoveryActions(ref.watch(displayRecoveryRepositoryProvider));
