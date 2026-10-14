import 'package:cloud_board/src/app/feature/device/domain/entities/display_connection_state.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

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

Duration? _noAutomaticPairingRetry(int attempt, Object error) => null;

@Riverpod(keepAlive: true, retry: _noAutomaticPairingRetry)
Stream<DisplayConnectionState> displayConnectionState(Ref ref) =>
    ref.watch(devicePairingActionsProvider).watchConnectionState();

@Riverpod(keepAlive: true, retry: _noAutomaticPairingRetry)
class DevicePairingController extends _$DevicePairingController {
  @override
  Future<DevicePairing> build() {
    ref.watch(devicePairingActionsProvider);
    final connection = ref.watch(displayConnectionStateProvider);
    _epoch++;
    if (connection.hasError) {
      Error.throwWithStackTrace(
        connection.error!,
        connection.stackTrace ?? StackTrace.current,
      );
    }
    final current = connection.value;
    if (current?.phase == DisplayConnectionPhase.failed) {
      ref
          .read(errorReporterProvider)
          .capture(
            current!.error!,
            current.stack ?? StackTrace.current,
            action: 'pairing.verify',
          );
      // A terminal generation stays stopped. Only explicit refresh or a new
      // physical connection may start another bounded verification cycle.
      Error.throwWithStackTrace(
        current.error!,
        current.stack ?? StackTrace.current,
      );
    }
    return _issue();
  }

  int _epoch = 0;

  Future<void> refresh() async {
    final epoch = ++_epoch;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _issue(retryConnection: true));
    if (ref.mounted && epoch == _epoch) state = result;
  }

  Future<DevicePairing> _issue({bool retryConnection = false}) async {
    final epoch = _epoch;
    try {
      return await ref
          .read(devicePairingActionsProvider)
          .issue(
            deviceId: await ref.read(deviceIdProvider.future),
            retryConnection: retryConnection,
          );
    } catch (error, stack) {
      if (ref.mounted && epoch == _epoch) {
        final phase = ref.read(displayConnectionStateProvider).value?.phase;
        ref
            .read(errorReporterProvider)
            .capture(
              error,
              stack,
              action: phase == null || phase == DisplayConnectionPhase.idle
                  ? 'pairing.issue_code'
                  : 'pairing.verify',
            );
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
        devices.where((item) => item.paired).length >= profile.displayLimit &&
        !devices.any((item) => item.paired && item.pairingCode == code)) {
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
    List<String> replaceDeviceIds = const [],
  }) => _run(
    'display_state',
    () => ref
        .read(devicePairingActionsProvider)
        .setDisplayState(
          deviceId: deviceId,
          displayState: displayState,
          replaceDeviceIds: replaceDeviceIds,
        ),
  );
}

/// Re-evaluates stale heartbeats even when the database emits no new values.
@riverpod
Stream<int> displayHealthNow(Ref ref) async* {
  final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
  yield DateTime.now().millisecondsSinceEpoch + offset;
  yield* Stream.periodic(
    const Duration(seconds: 5),
    (_) => DateTime.now().millisecondsSinceEpoch + offset,
  );
}
