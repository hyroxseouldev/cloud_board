import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

abstract interface class DevicePairingRepository {
  Future<DevicePairing> issue({required String deviceId});
  Stream<List<DisplayDevice>> watchDevices();
  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  });
  Future<void> unpair(String deviceId);
  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
  });
  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  });
}
