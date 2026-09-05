import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/device_mode.dart';
import '../../domain/repositories/device_mode_repository.dart';
import '../datasources/device_mode_local_data_source.dart';

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
