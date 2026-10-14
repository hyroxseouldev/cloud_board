import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';

class DisplayRecoveryDataSource {
  DisplayRecoveryDataSource(this.database, this.functions, this.ownerId);
  final FirebaseDatabase database;
  final FirebaseFunctions functions;
  final String? ownerId;
  bool _disposed = false;
  void dispose() => _disposed = true;
  void _scope() {
    if (_disposed || ownerId == null) throw StateError('매장 연결을 다시 확인해 주세요.');
  }

  Stream<DisplayRecoveryRequest?> watch(String deviceId) {
    if (ownerId == null) return Stream.value(null);
    return database
        .ref('users/$ownerId/displayRecovery/$deviceId/current')
        .onValue
        .map((event) {
          _scope();
          return decodeDisplayRecovery(event.snapshot.value);
        });
  }

  Future<DisplayRecoveryRequest> request(
    String deviceId,
    String operationId,
  ) async {
    _scope();
    final installation = await displayInstallationInfo();
    _scope();
    final result = await functions
        .httpsCallable(
          'requestDisplayRecovery',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Object?>({
          'deviceId': deviceId,
          'operationId': operationId,
          'appVersion': installation['appVersion'] ?? '',
          'appBuild': installation['appBuild'] ?? '',
        });
    _scope();
    final request = decodeDisplayRecovery(result.data);
    if (request == null || request.deviceId != deviceId) {
      throw const FormatException('TV 복구 요청 응답을 확인하지 못했습니다.');
    }
    return request;
  }

  Future<void> report(
    DisplayRecoveryRequest request,
    DisplayRecoveryStatus status, {
    String? sessionId,
    int? revision,
    String? errorCode,
  }) async {
    _scope();
    final installation = await displayInstallationInfo();
    _scope();
    await functions
        .httpsCallable(
          'reportDisplayRecovery',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
        )
        .call<void>({
          'deviceId': request.deviceId,
          'operationId': request.operationId,
          'status': status.name,
          'appVersion': installation['appVersion'] ?? '',
          'appBuild': installation['appBuild'] ?? '',
          'sessionId': ?sessionId,
          'revision': ?revision,
          'errorCode': ?errorCode,
        });
  }
}

DisplayRecoveryRequest? decodeDisplayRecovery(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) throw const FormatException('잘못된 TV 복구 상태입니다.');
  final status = DisplayRecoveryStatus.values
      .where((e) => e.name == raw['status'])
      .firstOrNull;
  if (status == null ||
      raw['operationId'] is! String ||
      raw['deviceId'] is! String ||
      raw['requestedAtMs'] is! num ||
      raw['expiresAtMs'] is! num) {
    throw const FormatException('잘못된 TV 복구 상태입니다.');
  }
  return DisplayRecoveryRequest(
    operationId: raw['operationId'] as String,
    deviceId: raw['deviceId'] as String,
    status: status,
    requestedAtMs: (raw['requestedAtMs'] as num).toInt(),
    expiresAtMs: (raw['expiresAtMs'] as num).toInt(),
    errorCode: raw['errorCode'] as String?,
    errorId: raw['errorId'] as String?,
    verifiedAtMs: (raw['verifiedAtMs'] as num?)?.toInt(),
    sessionId: raw['sessionId'] as String?,
    revision: (raw['revision'] as num?)?.toInt(),
  );
}
