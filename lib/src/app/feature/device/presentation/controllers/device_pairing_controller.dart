import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';

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
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(userProfileControllerProvider.future);
      final devices = await ref.read(displayDevicesProvider.future);
      if (devices.where((item) => item.paired).length >= profile.displayLimit) {
        throw StateError(
          '현재 등급에서는 디스플레이를 ${profile.displayLimit}대까지 연결할 수 있습니다.',
        );
      }
      await ref
          .read(devicePairingActionsProvider)
          .claim(code: code, name: name, zoneName: zoneName);
    });
    return !state.hasError;
  }

  Future<void> unpair(String deviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(devicePairingActionsProvider).unpair(deviceId),
    );
  }

  Future<bool> setDisplayState({
    required String deviceId,
    required String displayState,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(devicePairingActionsProvider)
          .setDisplayState(deviceId: deviceId, displayState: displayState),
    );
    return !state.hasError;
  }
}
