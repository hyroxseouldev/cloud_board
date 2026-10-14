import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';

abstract interface class DisplayRecoveryRepository {
  Stream<DisplayRecoveryRequest?> watch(String deviceId);
  Future<DisplayRecoveryRequest> request(String deviceId, String operationId);
  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  });
}
