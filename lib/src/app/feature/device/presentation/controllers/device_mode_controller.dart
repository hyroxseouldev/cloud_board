import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_mode_actions.dart';

part 'device_mode_controller.g.dart';

@Riverpod(keepAlive: true)
class DeviceModeController extends _$DeviceModeController {
  DeviceMode _currentMode = DeviceMode.controller;

  DeviceMode get currentMode => _currentMode;

  @override
  Future<DeviceMode> build() async {
    _currentMode = await (await ref.watch(loadDeviceModeProvider.future))();
    if (await ref.watch(androidTvProvider.future)) {
      _currentMode = DeviceMode.display;
      await (await ref.read(saveDeviceModeProvider.future))(_currentMode);
    }
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
