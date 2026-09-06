import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';

part 'device_pairing_controller.g.dart';

@Riverpod(keepAlive: true)
class DevicePairingController extends _$DevicePairingController {
  @override
  Future<DevicePairing> build() => _issue();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_issue);
  }

  Future<DevicePairing> _issue() async => ref
      .read(devicePairingActionsProvider)
      .issue(deviceId: await ref.read(deviceIdProvider.future));
}

@Riverpod(keepAlive: true)
Stream<List<DisplayDevice>> displayDevices(Ref ref) =>
    ref.watch(devicePairingRepositoryProvider).watchDevices();

@riverpod
class DeviceClaimController extends _$DeviceClaimController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> claim({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(devicePairingActionsProvider)
          .claim(code: code, name: name, zoneName: zoneName),
    );
    return !state.hasError;
  }

  Future<void> unpair(String deviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(devicePairingActionsProvider).unpair(deviceId),
    );
  }
}
