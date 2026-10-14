import 'package:cloud_board/src/app/feature/device/domain/entities/display_connection_state.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

abstract interface class DevicePairingRepository {
  Stream<DisplayConnectionState> watchConnectionState();
  Future<DevicePairing> issue({
    required String deviceId,
    bool retryConnection = false,
  });
  Stream<List<DisplayDevice>> watchDevices();
  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  });
  Future<void> unpair(String deviceId);
  Future<void> rename({
    required String deviceId,
    required String name,
    required String zoneName,
  });

  Future<void> savePreferences(String deviceId, DisplayPreferences preferences);

  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
    List<String> replaceDeviceIds = const [],
  });
  Future<void> identify(String deviceId, String nonce, int expiresAtMs);

  Future<void> acknowledgeIdentification(String deviceId, String nonce);

  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  });
}
