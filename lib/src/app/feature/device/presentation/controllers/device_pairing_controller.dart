import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_pairing_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/device_pairing_actions.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';

part 'device_pairing_controller.g.dart';

@Riverpod(keepAlive: true)
class DevicePairingController extends _$DevicePairingController {
  @override
  Future<DevicePairing> build() {
    ref.watch(devicePairingActionsProvider);
    return _issue();
  }

  int _epoch = 0;

  Future<void> refresh() async {
    final epoch = ++_epoch;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_issue);
    if (ref.mounted && epoch == _epoch) state = result;
  }

  Future<DevicePairing> _issue() async {
    try {
      return await ref
          .read(devicePairingActionsProvider)
          .issue(deviceId: await ref.read(deviceIdProvider.future));
    } catch (error, stack) {
      if (ref.mounted) {
        ref
            .read(errorReporterProvider)
            .capture(error, stack, action: 'pairing.issue_code');
      }
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
Stream<List<DisplayDevice>> displayDevices(Ref ref) => ref
    .watch(devicePairingRepositoryProvider)
    .watchDevices()
    .handleError((Object error, StackTrace stack) {
      ref
          .read(errorReporterProvider)
          .capture(error, stack, action: 'pairing.stream');
      Error.throwWithStackTrace(error, stack);
    });

@riverpod
class DeviceClaimController extends _$DeviceClaimController {
  bool _pending = false;
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _run(String phase, Future<void> Function() operation) async {
    if (_pending || state.isLoading) return false;
    _pending = true;
    final started = Stopwatch()..start();
    final reporter = ref.read(errorReporterProvider);
    reporter.breadcrumb('pairing.$phase');
    state = const AsyncLoading();
    // Even after the UI deadline, do not send a duplicate mutation while the
    // original SDK operation is unresolved. Its eventual result refreshes data.
    final request = Future<void>.sync(operation).whenComplete(() {
      _pending = false;
      if (ref.mounted) ref.invalidate(displayDevicesProvider);
    });
    final result = await AsyncValue.guard(
      () => request.timeout(const Duration(seconds: 20)),
    );
    if (result.hasError) {
      reporter.capture(
        result.error!,
        result.stackTrace ?? StackTrace.current,
        action: 'pairing.$phase',
        context: {'elapsedMs': started.elapsedMilliseconds},
      );
    }
    if (!ref.mounted) return false;
    state = result;
    return !result.hasError;
  }

  Future<bool> claim({
    required String code,
    required String name,
    required String zoneName,
  }) => _run('claim', () async {
    final profileFuture = Future.sync(
      () => ref.read(userProfileControllerProvider.future),
    );
    final devicesFuture = Future.sync(
      () => ref.read(displayDevicesProvider.future),
    );
    final values = await Future.wait<Object>([profileFuture, devicesFuture]);
    if (!ref.mounted) return;
    final profile = values[0] as UserProfile;
    final devices = values[1] as List<DisplayDevice>;
    if (!profile.hasPlanDisplayPolicy &&
        devices.where((item) => item.paired).length >= profile.displayLimit) {
      throw StateError(
        '현재 등급에서는 디스플레이를 ${profile.displayLimit}대까지 연결할 수 있습니다.',
      );
    }
    await ref
        .read(devicePairingActionsProvider)
        .claim(code: code, name: name, zoneName: zoneName);
  });
  Future<bool> unpair(String deviceId) => _run(
    'unpair',
    () => ref.read(devicePairingActionsProvider).unpair(deviceId),
  );
  Future<bool> rename({
    required String deviceId,
    required String name,
    required String zoneName,
  }) => _run(
    'rename',
    () => ref
        .read(devicePairingActionsProvider)
        .rename(deviceId: deviceId, name: name, zoneName: zoneName),
  );
  Future<bool> savePreferences(
    String deviceId,
    DisplayPreferences preferences,
  ) => _run(
    'preferences',
    () => ref
        .read(devicePairingActionsProvider)
        .savePreferences(deviceId, preferences),
  );
  Future<bool> setDisplayState({
    required String deviceId,
    required String displayState,
  }) => _run(
    'display_state',
    () => ref
        .read(devicePairingActionsProvider)
        .setDisplayState(deviceId: deviceId, displayState: displayState),
  );
}
