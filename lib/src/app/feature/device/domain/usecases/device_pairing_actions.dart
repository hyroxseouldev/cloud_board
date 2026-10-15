import 'package:cloud_board/src/app/feature/device/domain/entities/display_connection_state.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';

part 'device_pairing_actions.g.dart';

class DevicePairingActions {
  const DevicePairingActions(this._repository);

  final DevicePairingRepository _repository;

  Stream<DisplayConnectionState> watchConnectionState() =>
      _repository.watchConnectionState();

  Future<DevicePairing> issue({
    required String deviceId,
    bool retryConnection = false,
  }) => _repository.issue(deviceId: deviceId, retryConnection: retryConnection);

  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  }) => _repository.claim(code: code, name: name, zoneName: zoneName);

  Future<void> unpair(String deviceId) => _repository.unpair(deviceId);

  Future<void> rename({
    required String deviceId,
    required String name,
    required String zoneName,
  }) => _repository.rename(deviceId: deviceId, name: name, zoneName: zoneName);

  Future<void> savePreferences(
    String deviceId,
    DisplayPreferences preferences,
  ) => _repository.savePreferences(deviceId, preferences);

  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
    List<String> replaceDeviceIds = const [],
  }) => _repository.setDisplayState(
    deviceId: deviceId,
    displayState: displayState,
    replaceDeviceIds: replaceDeviceIds,
  );

  Future<void> acknowledge({
    required String deviceId,
    required String sessionId,
    required int revision,
  }) => _repository.acknowledge(
    deviceId: deviceId,
    sessionId: sessionId,
    revision: revision,
  );
}

@riverpod
DevicePairingActions devicePairingActions(Ref ref) =>
    DevicePairingActions(ref.watch(devicePairingRepositoryProvider));
