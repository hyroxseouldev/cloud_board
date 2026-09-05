import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/device_mode.dart';
import '../../domain/usecases/device_mode_actions.dart';

part 'device_mode_controller.g.dart';

@Riverpod(keepAlive: true)
class DeviceModeController extends _$DeviceModeController {
  DeviceMode _currentMode = DeviceMode.controller;

  DeviceMode get currentMode => _currentMode;

  @override
  Future<DeviceMode> build() async {
    _currentMode = await (await ref.watch(loadDeviceModeProvider.future))();
    return _currentMode;
  }

  Future<bool> setMode(DeviceMode mode) async {
    if (_currentMode == mode) return true;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await (await ref.read(saveDeviceModeProvider.future))(mode);
      return mode;
    });
    if (!result.hasError) _currentMode = mode;
    state = result;
    return !result.hasError;
  }
}
