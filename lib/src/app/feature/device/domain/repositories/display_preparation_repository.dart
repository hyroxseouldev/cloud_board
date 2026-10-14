import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';

abstract interface class DisplayPreparationRepository {
  Future<void> request(DisplayPreparation request);
  Future<void> cancel(String sessionId);
  Stream<DisplayPreparation?> watchRequest(String deviceId);
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts();
  Future<DisplayPreparation?> current();
  Future<Map<String, DisplayPreparationReceipt>> receipts();
  Future<void> respond(
    String deviceId,
    DisplayPreparation request, {
    required bool ready,
    required int imageCount,
    required bool audioReady,
  });
  Future<void> heartbeat(String deviceId, {bool ready = false});
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  });
}
