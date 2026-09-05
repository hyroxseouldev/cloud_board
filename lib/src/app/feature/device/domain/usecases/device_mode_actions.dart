import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/device_mode_repository_impl.dart';
import '../entities/device_mode.dart';
import '../repositories/device_mode_repository.dart';

part 'device_mode_actions.g.dart';

class LoadDeviceMode {
  const LoadDeviceMode(this._repository);
  final DeviceModeRepository _repository;
  Future<DeviceMode> call() => _repository.load();
}

class SaveDeviceMode {
  const SaveDeviceMode(this._repository);
  final DeviceModeRepository _repository;
  Future<void> call(DeviceMode mode) => _repository.save(mode);
}

@riverpod
Future<LoadDeviceMode> loadDeviceMode(Ref ref) async =>
    LoadDeviceMode(await ref.watch(deviceModeRepositoryProvider.future));

@riverpod
Future<SaveDeviceMode> saveDeviceMode(Ref ref) async =>
    SaveDeviceMode(await ref.watch(deviceModeRepositoryProvider.future));
