import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';

abstract interface class DeviceModeRepository {
  Future<DeviceMode> load();
  Future<void> save(DeviceMode mode);
}
