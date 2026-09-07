import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';

part 'device_pairing_actions.g.dart';

class DevicePairingActions {
  const DevicePairingActions(this._repository);

  final DevicePairingRepository _repository;

  Future<DevicePairing> issue({required String deviceId}) =>
      _repository.issue(deviceId: deviceId);

  Future<void> claim({
    required String code,
    required String name,
    required String zoneName,
  }) => _repository.claim(code: code, name: name, zoneName: zoneName);

  Future<void> unpair(String deviceId) => _repository.unpair(deviceId);

  Future<void> setDisplayState({
    required String deviceId,
    required String displayState,
  }) => _repository.setDisplayState(
    deviceId: deviceId,
    displayState: displayState,
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
