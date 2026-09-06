import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_mode_repository.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_mode_local_data_source.dart';

part 'device_mode_repository_impl.g.dart';

class DeviceModeRepositoryImpl implements DeviceModeRepository {
  const DeviceModeRepositoryImpl(this._local);

  final DeviceModeLocalDataSource _local;

  @override
  Future<DeviceMode> load() async => DeviceMode.fromStorage(_local.load());

  @override
  Future<void> save(DeviceMode mode) => _local.save(mode.storageValue);
}

@riverpod
Future<DeviceModeRepository> deviceModeRepository(Ref ref) async =>
    DeviceModeRepositoryImpl(
      DeviceModeLocalDataSource(await SharedPreferences.getInstance()),
    );

@Riverpod(keepAlive: true)
Future<String> deviceId(Ref ref) async =>
    DeviceIdentityLocalDataSource(await SharedPreferences.getInstance())
        .loadOrCreate();
